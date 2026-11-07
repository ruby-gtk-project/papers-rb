# frozen_string_literal: true

require 'adwaita'

# InkTransformation turns the raw points a pen or finger drags across the
# page into the smoothed, simplified path an ink annotation actually stores.
#
# Ported from upstream's shell/src/ink_transformation.rs. Upstream smooths a
# stroke with the `ink-stroke-modeler-rs` crate, which has no Ruby binding
# (this is not one of the gems this port is required to wire in — libspelling
# and libxmlb are — so there is nothing to bind to here), so
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
# What upstream wires through AnnotationsContext.register_ink_transformation
# — reading an AnnotationInk's recorded time_list, smoothing it and writing
# the result back as the annotation's ink_list — is not ported: this port has
# no AnnotationsContext or AnnotationInk yet (the papers_document/papers_view
# backend those come from is out of this round's scope). The two transforms
# below are complete and ready for whatever ink-drawing widget calls them
# once that backend exists.
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
