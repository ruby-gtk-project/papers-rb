# frozen_string_literal: true

require 'gdk_pixbuf2'

# SignatureImageProcessing turns a hand-drawn signature's pixbuf into a
# transparent-background stencil: ink becomes opaque black, everything else
# becomes fully transparent, regardless of whether the drawing surface gave
# dark ink on a light background or light ink on a dark one.
#
# Ported from upstream's shell/src/signature_image_processing.rs, which does
# this with the `image` and `imageproc` crates: an Otsu threshold split into
# ink/background, then a reduction to a black-or-transparent RGBA image.
# RawImageData's split into from_pixbuf / do_signature_threshold / create_pixbuf
# existed upstream to move work off the main thread; this port keeps the same
# three steps as the module's three methods so a caller can still do the
# threshold on a background thread and only touch GdkPixbuf on the main one.
#
module SignatureImageProcessing
  # Minimum alpha value to consider a pixel opaque (0-255 scale). Pixels
  # below this are treated as transparent background.
  ALPHA_OPAQUE_THRESHOLD = 128

  # After Otsu + ToZero thresholding, pixels below this intensity are
  # classified as "dark" (potential ink on a light background).
  INK_INTENSITY_THRESHOLD = 5

  RawImageData = Struct.new(:data, :width, :height, :n_channels, :rowstride) do
    # Processes this image's pixels in place of Rust's
    # do_signature_threshold, returning a new RawImageData holding RGBA
    # ink-or-transparent bytes at the same dimensions.
    def do_signature_threshold
      raise(ArgumentError, 'Image must have at least 3 channels (RGB)') if n_channels < 3

      has_alpha = n_channels >= 4
      gray = SignatureImageProcessing.gray_image(data, width, height, n_channels, rowstride, has_alpha)
      threshold_value = SignatureImageProcessing.otsu_level(gray)
      thresholded = SignatureImageProcessing.threshold_to_zero(gray, threshold_value)
      ink_is_dark = SignatureImageProcessing.ink_is_dark?(
        data,
        width,
        height,
        n_channels,
        rowstride,
        has_alpha,
        thresholded,
      )
      rgba = SignatureImageProcessing.ink_or_transparent(
        data,
        width,
        height,
        n_channels,
        rowstride,
        has_alpha,
        thresholded,
        ink_is_dark,
      )

      RawImageData.new(rgba, width, height, 4, width * 4)
    end
  end

  class << self
    # Extracts raw pixel data from pixbuf. Call this on the main thread, as
    # upstream's comment on RawImageData::from_pixbuf says.
    def raw_image_data(pixbuf)
      RawImageData.new(
        pixbuf.read_pixel_bytes.to_s,
        pixbuf.width,
        pixbuf.height,
        pixbuf.n_channels,
        pixbuf.rowstride,
      )
    end

    # Builds a pixbuf from processed RawImageData. Call this on the main
    # thread, as upstream's comment on RawImageData::create_pixbuf says.
    def pixbuf(raw_image_data)
      GdkPixbuf::Pixbuf.new(
        data: raw_image_data.data,
        colorspace: :rgb,
        has_alpha: true,
        bits_per_sample: 8,
        width: raw_image_data.width,
        height: raw_image_data.height,
        rowstride: raw_image_data.rowstride,
      )
    end

    # Builds the grayscale byte string threshold computation runs on.
    # Transparent pixels are treated as white background so they do not
    # skew the Otsu threshold.
    def gray_image(data, width, height, n_channels, rowstride, has_alpha)
      String.new.b.tap do |gray|
        (0...height).each do |y|
          (0...width).each do |x|
            idx = (y * rowstride) + (x * n_channels)
            alpha = has_alpha ? data.getbyte(idx + 3) : 255

            gray << if alpha < ALPHA_OPAQUE_THRESHOLD
              255.chr
            else
              r = data.getbyte(idx)
              g = data.getbyte(idx + 1)
              b = data.getbyte(idx + 2)
              ((0.299 * r) + (0.587 * g) + (0.114 * b)).to_i.chr
            end
          end
        end
      end
    end

    # Otsu's method: the intensity level that maximizes the between-class
    # variance of the histogram split at that level.
    def otsu_level(gray_image)
      histogram = Array.new(256, 0)
      gray_image.each_byte { |byte| histogram[byte] += 1 }

      total = gray_image.bytesize
      sum_all = histogram.each_with_index.sum { |count, level| count * level }

      sum_below = 0
      weight_below = 0
      best_level = 0
      best_variance = -1.0

      histogram.each_with_index do |count, level|
        weight_below += count
        next if weight_below.zero?

        weight_above = total - weight_below
        break if weight_above.zero?

        sum_below += count * level
        mean_below = sum_below.to_f / weight_below
        mean_above = (sum_all - sum_below).to_f / weight_above
        variance = weight_below * weight_above * ((mean_below - mean_above)**2)

        if variance > best_variance
          best_variance = variance
          best_level = level
        end
      end

      best_level
    end

    # imageproc::contrast::ThresholdType::ToZero: a pixel keeps its value
    # when it is above the threshold, and becomes 0 otherwise.
    def threshold_to_zero(gray_image, threshold_value)
      String.new.b.tap do |out|
        gray_image.each_byte do |byte|
          out << (byte > threshold_value ? byte.chr : 0.chr)
        end
      end
    end

    # Whether the ink is the darker group. If dark pixels outnumber light
    # ones post-threshold, the drawing has light ink on a dark background
    # (such as a screenshot taken in dark mode), so the ink is the lighter
    # group instead.
    def ink_is_dark?(data, width, height, n_channels, rowstride, has_alpha, thresholded)
      dark_count = 0
      light_count = 0

      (0...height).each do |y|
        (0...width).each do |x|
          idx = (y * rowstride) + (x * n_channels)
          alpha = has_alpha ? data.getbyte(idx + 3) : 255
          next if alpha < ALPHA_OPAQUE_THRESHOLD

          intensity = thresholded.getbyte((y * width) + x)
          if intensity < INK_INTENSITY_THRESHOLD
            dark_count += 1
          else
            light_count += 1
          end
        end
      end

      dark_count <= light_count
    end

    # Builds the final RGBA bytes: opaque black where the thresholded
    # image says ink, fully transparent everywhere else (including every
    # pixel that started out transparent).
    def ink_or_transparent(data, width, height, n_channels, rowstride, has_alpha, thresholded, ink_is_dark)
      String.new.b.tap do |rgba|
        (0...height).each do |y|
          (0...width).each do |x|
            idx = (y * rowstride) + (x * n_channels)
            orig_alpha = has_alpha ? data.getbyte(idx + 3) : 255

            if orig_alpha < ALPHA_OPAQUE_THRESHOLD
              rgba << [0, 0, 0, 0].pack('C4')
            else
              intensity = thresholded.getbyte((y * width) + x)
              is_ink =
                if ink_is_dark
                  intensity < INK_INTENSITY_THRESHOLD
                else
                  intensity >= INK_INTENSITY_THRESHOLD
                end

              rgba << (is_ink ? [0, 0, 0, 255].pack('C4') : [0, 0, 0, 0].pack('C4'))
            end
          end
        end
      end
    end
  end
end
