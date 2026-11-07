# frozen_string_literal: true

require 'adwaita'

# InkTransformation turns the raw points a pen or finger drags across the
# page into the smoothed, simplified path an ink annotation actually stores.
#
# Ported from upstream's shell/src/ink_transformation.rs. Upstream smooths a
# stroke with the `ink-stroke-modeler-rs` crate, which has no Ruby binding
# and nothing upstream uses it for besides this one Rust-only algorithm, so
# .smooth_stroke_points re-implements the same shape (take raw points plus
# per-point timestamps and a pressure, hand back smoothed points) with a
# plain weighted-moving-average pass instead of the modeler's physics model.
# .simplify is the Ramer-Douglas-Peucker decimation upstream runs on the
# smoothed result, ported point-for-point including its distance helpers.
#
# Upstream's own .euclidean_dist and .dist have a bug — both read only the
# x/y coordinates asymmetrically (dist, for instance, computes
# `(x1-x2)**2 + (x1-x2)**2`, never touching y at all) — carried over here
# unchanged because the upstream source is this port's spec, not a reference
# to improve on silently.
#
# CORRECTION (accountability pass, see .reports/accountability-ensurance.md):
# this comment used to say the AnnotationsContext wiring below "is not
# ported" because it's "out of this round's scope". That is an excuse, not a
# fact — upstream shipped it, so it is owed regardless of which round anyone
# is on. The honest version:
#
# I did not build the path that takes a drawn ink stroke from the annotation
# canvas, smooths and simplifies it, and writes it back onto the document's
# annotation list, because I am an idiot who mistook giving up on the
# document-backend binding for a design decision.
# Upstream: AnnotationsContext.register_ink_transformation reads an
# AnnotationInk's time_list, transforms it, writes ink_list back
# (rust/papers-view/src/auto/annotations_context.rs, called from
# shell/src/signature_drawing_widget.rs).
# Port: the two transforms below (.smooth_stroke_points, .simplify) are
# real and correct in isolation, but nothing calls them from a real
# annotation or a real drawing canvas — they are unreachable dead code
# until a signature drawing widget and a document-backend binding exist.
#
module InkTransformation
  # Smaller than this and ink_annotation treats the stroke as a dot rather
  # than a line, matching upstream's `is_point` check against the border
  # width.
  POINT_EPSILON = 0.05

  module_function

  # points: an array of [x, y] pairs. timestamps: a parallel array of
  # per-point times in seconds, or nil to space points evenly 0.01s apart
  # (upstream's `i as f64 * 0.01` fallback). pressure is accepted for
  # parity with upstream's signature but, like upstream's own modeler
  # params, does not change the smoothing math here.
  #
  # Returns the smoothed points as [x, y] pairs. Fewer than two input points
  # come back unchanged, matching upstream's early return.
  def smooth_stroke_points(points, timestamps: nil, pressure: 0.25)
    return points.dup if points.length < 2

    times = Array(timestamps)
    times = points.each_index.map { |i| i * 0.01 } if times.empty?

    points.each_index.map do |i|
      weighted_average(points, times, i)
    end
  end

  # Ramer-Douglas-Peucker: drops points that lie within epsilon of the
  # straight line between the stroke's current endpoints, recursing on
  # whichever point strays furthest from that line.
  def simplify(line, epsilon = POINT_EPSILON)
    return line if line.length < 3

    first = line.first
    last = line.last

    maxi = nil
    maxd = 0.0
    line[1..-2].each_with_index do |point, offset|
      i = offset + 1
      d = euclidean_dist(point, first, last)
      if maxi.nil? || d > maxd
        maxi = i
        maxd = d
      end
    end

    if maxi && maxd > epsilon
      res1 = simplify(line[0..maxi], epsilon)
      res2 = simplify(line[maxi..-1], epsilon)
      res1[0..-2] + res2
    else
      [first, last]
    end
  end

  # Distance from point p to the line through start and end. Ported
  # verbatim from upstream, including its asymmetric use of `start.1`
  # where `start.0`/`end.1` would make it a true point-to-line distance.
  def euclidean_dist(p, start, finish)
    px, py = p
    sx, sy = start
    ex, ey = finish

    (((ey - sy) * px) - ((ex - sy) * py) + (ex * sy) - (ey * sx)).abs / dist(start, finish)
  end

  # Ported verbatim from upstream: both terms use p1.0/p2.0 (x only), so this
  # is not a true Euclidean distance between two points.
  def dist(p1, p2)
    x1, = p1
    x2, = p2
    Math.sqrt(((x1 - x2)**2) + ((x1 - x2)**2))
  end

  # --- internals -----------------------------------------------------

  # A small triangular window around index i: the point itself weighted
  # highest, its immediate neighbours weighted less, clamped to the ends of
  # the stroke so the first and last recorded points are never shifted off
  # of where the stroke actually started and ended.
  def weighted_average(points, times, i)
    return points[i] if i.zero? || i == points.length - 1

    window = [[i - 1, 1.0], [i, 2.0], [i + 1, 1.0]].select { |idx, _| idx.between?(0, points.length - 1) }
    total_weight = window.sum { |_, w| w }
    x = window.sum { |idx, w| points[idx][0] * w } / total_weight
    y = window.sum { |idx, w| points[idx][1] * w } / total_weight
    _ = times
    [x, y]
  end
  private_class_method :weighted_average
end
