import 'dart:math' as math;

/// A 2-D point in character space (1024 box, y up – Make Me a Hanzi).
class Pt {
  final double x, y;
  const Pt(this.x, this.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator *(double k) => Pt(x * k, y * k);
  double dist(Pt o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
  double get len => math.sqrt(x * x + y * y);
}

double pathLength(List<Pt> pts) {
  var l = 0.0;
  for (var i = 1; i < pts.length; i++) {
    l += pts[i].dist(pts[i - 1]);
  }
  return l;
}

/// Resamples a polyline into [n] evenly spaced points.
List<Pt> resample(List<Pt> pts, int n) {
  if (pts.isEmpty) return const [];
  if (pts.length == 1) return List.filled(n, pts.first);
  final total = pathLength(pts);
  if (total == 0) return List.filled(n, pts.first);
  final step = total / (n - 1);
  final out = <Pt>[pts.first];
  var acc = 0.0;
  var prev = pts.first;
  var i = 1;
  while (i < pts.length && out.length < n) {
    final cur = pts[i];
    final d = prev.dist(cur);
    if (acc + d >= step && d > 0) {
      final t = (step - acc) / d;
      final q = prev + (cur - prev) * t;
      out.add(q);
      prev = q;
      acc = 0;
    } else {
      acc += d;
      prev = cur;
      i++;
    }
  }
  while (out.length < n) {
    out.add(pts.last);
  }
  return out;
}

class StrokeResult {
  final bool ok;
  final double avgDist;
  final String? reason;
  const StrokeResult(this.ok, this.avgDist, [this.reason]);
}

/// Compares a user-drawn stroke with the reference median.
///
/// Both are in character space. [leniency] > 1 is more forgiving.
StrokeResult matchStroke(List<Pt> user, List<Pt> median,
    {double leniency = 1.0}) {
  if (user.length < 2 || median.length < 2) {
    return const StrokeResult(false, double.infinity, 'Nét quá ngắn');
  }
  final medLen = pathLength(median);
  final userLen = pathLength(user);
  if (userLen < 25) {
    return const StrokeResult(false, double.infinity, 'Nét quá ngắn');
  }

  // Short strokes (dots) get a more generous distance budget relative
  // to their size, long strokes are judged mostly by shape.
  final distThreshold = (medLen < 150 ? 170.0 : 150.0) * leniency;
  final endThreshold = (medLen < 150 ? 210.0 : 190.0) * leniency;

  const n = 24;
  final u = resample(user, n);
  final m = resample(median, n);
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    sum += u[i].dist(m[i]);
  }
  final avg = sum / n;

  // Direction: overall vector must broadly agree.
  final du = u.last - u.first;
  final dm = m.last - m.first;
  if (du.len > 0 && dm.len > 40) {
    final cos = (du.x * dm.x + du.y * dm.y) / (du.len * dm.len);
    if (cos < 0) {
      return StrokeResult(false, avg, 'Sai chiều nét');
    }
  }

  if (u.first.dist(m.first) > endThreshold) {
    return StrokeResult(false, avg, 'Sai điểm bắt đầu');
  }
  if (u.last.dist(m.last) > endThreshold) {
    return StrokeResult(false, avg, 'Sai điểm kết thúc');
  }
  final ratio = userLen / math.max(medLen, 1);
  if (medLen > 150 && (ratio < 0.4 || ratio > 2.2)) {
    return StrokeResult(false, avg, ratio < 1 ? 'Nét quá ngắn' : 'Nét quá dài');
  }
  if (avg > distThreshold) {
    return StrokeResult(false, avg, 'Sai hình dạng nét');
  }
  return StrokeResult(true, avg);
}

/// Score 0–100 for a character given total mistakes and stroke count.
int writingScore(int mistakes, int strokes) {
  if (strokes == 0) return 0;
  final s = 100 - (mistakes * 100 / (strokes * 2)).round();
  return s.clamp(0, 100);
}
