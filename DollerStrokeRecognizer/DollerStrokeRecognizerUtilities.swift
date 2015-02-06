import Foundation
import CoreGraphics

// $N Multistroke Recognizer Functions

// templates = {
//     "name1": {
//         "strokes" : [ [ CGPoint, CGPoint, .. ], .. ],
//         "vectors" : [ CGPoint, CGPoint, ... ] } ],
//     },
//     "name2": {
//         "strokes" : [ [ CGPoint, CGPoint, .. ], .. ],
//         "vectors" : [ CGPoint, CGPoint, ... ] } ],
//     },
//     "name3": {
//         "strokes" : [ [ CGPoint, CGPoint, .. ], .. ],
//         "vectors" : [ CGPoint, CGPoint, ... ] } ],
//     },
//     ...
// }

func Recognize(points: [CGPoint], vector: CGPoint, templates: [String: [String: [Any]]]) -> (name: String, score: Float) {
    var b = Float.infinity // best distance
    var n = "" // best template name
    for (name, template) in templates {
        var strokes = template["strokes"] as [[CGPoint]]
        var vectors = template["vectors"] as [CGPoint]
        for i in 0..<strokes.count {
            var templatePoints = strokes[0]
            var templateVector = vectors[0]
            if AngleBetweenVectors(vector, templateVector) <= 30 {
                var d = DistanceAtBestAngle(points, templatePoints)
                if d < b {
                    b = d
                    n = name
                }
            }
        }
    }
    var size: Float = 250
    var score = 1 - b / 0.5 * sqrtf(powf(size, 2) + powf(size, 2))
    return ("", 0.0)
}

func GenerateUnistrokePermutations(strokes: [[CGPoint]]) -> [CGPoint] {
    var N = 96 // num of points
    var size: Float = 250 // square size
    var delta: Float = 0.3 // threshold
    var O = CGPointZero // origin
    var I = N / 8 // start angle index
    
    var order = [Int](count: strokes.count, repeatedValue: 1)
    var orders = [[Int]]()
    heapPermutate(strokes.count, order, &orders)
    var M = makeUnistrokes(strokes, orders)
    var vectors = [CGPoint]()
    for i in 0..<M.count {
        var unistroke = M[i]
        unistroke = Resample(unistroke, N)
        var omega = IndicativeAngle(unistroke)
        unistroke = RotateBy(unistroke, -omega)
        unistroke = ScaleDimTo(unistroke, size, delta)
        unistroke = CheckRestoreOrientation(unistroke, omega, false)
        unistroke = TranslateTo(unistroke, O)

        var vector = CalcStartUnitVector(unistroke, I)
        vectors.append(vector)
    }
    return vectors
}

func heapPermutate(n: Int, order: [Int], inout orders: [[Int]]) {
    var tempOrder = order
    if n == 1 {
        orders.append(tempOrder)
    } else {
        for i in 0..<n {
            heapPermutate(n - 1, tempOrder, &orders)
            if n % 2 == 1 {
                swap(&tempOrder[0], &tempOrder[n-1])
            } else {
                swap(&tempOrder[i], &tempOrder[n-1])
            }
        }
    }
}

func makeUnistrokes(strokes: [[CGPoint]], orders: [[Int]]) -> [[CGPoint]] {
    var unistrokes = [[CGPoint]]()
    for order in orders {
        let power = Int(powf(Float(2), Float(order.count)))
        for b in 0..<power {
            var unistroke = [CGPoint]()
            for i in 0..<order.count {
                let stroke = strokes[order[i]] as [CGPoint]
                if ((b >> i) & 1) == 1 {
                    unistroke = stroke.reverse()
                } else {
                    unistroke = stroke
                }
            }
            unistrokes.append(unistroke)
        }
    }
    return unistrokes
}

func IndicativeAngle(points: [CGPoint]) -> Float {
    var c = Centroid(points)
    return atan2f(Float(c.y - points[0].y), Float(c.x - points[0].x))
}

func ScaleDimTo(points: [CGPoint], size: Float, delta: Float) -> [CGPoint] {
    var b = BoundingBox(points)
    var q = CGPointZero
    var newPoints = [CGPoint]()
    for point in points {
        if min(Float(b.width / b.height), Float(b.height / b.width)) <= delta {
            q.x = point.x * CGFloat(size) / max(b.width, b.height)
            q.y = point.y * CGFloat(size) / max(b.width, b.height)
        } else {
            q.x = point.x * CGFloat(size) / b.width
            q.y = point.y * CGFloat(size) / b.height
        }
        newPoints.append(q)
    }
    return newPoints
}

func CheckRestoreOrientation(points: [CGPoint], omega: Float, useBoundedRotationInvariance: Bool)
    -> [CGPoint] {
    var newPoints = points
    if useBoundedRotationInvariance {
        newPoints = RotateBy(points, omega)
    }
    return newPoints
}

func CalcStartUnitVector(points: [CGPoint], I: Int) -> CGPoint {
    var q = CGPointZero
    q.x = points[I].x - points[0].x
    q.y = points[I].y - points[0].y
    var v = CGPointZero
    v.x = q.x / CGFloat(sqrtf(Float(q.x * q.x + q.y * q.y)))
    v.y = q.y / CGFloat(sqrtf(Float(q.x * q.x + q.y * q.y)))
    return v
}

func AngleBetweenVectors(A: CGPoint, B: CGPoint) -> Float {
    return acosf(Float(A.x * B.x + A.y * B.y))
}

// $1 Unistroke Recognizer Functions

func Resample(points: [CGPoint], n: Int) -> [CGPoint] {
    var tempPoints = points
    var newPoints = [CGPoint]()
    let I = PathLength(tempPoints) / (Float(n) - 1)
    var D: Float = 0.0
    newPoints.append(tempPoints[0])
    for i in 1..<tempPoints.count {
        var d = Distance(tempPoints[i-1], tempPoints[i])
        var q = CGPointZero
        if (D + d) >= I {
            q.x = tempPoints[i-1].x + CGFloat((I-D)/d) * (tempPoints[i].x - tempPoints[i-1].x)
            q.y = tempPoints[i-1].y + CGFloat((I-D)/d) * (tempPoints[i].y - tempPoints[i-1].y)
            newPoints.append(q)
            tempPoints[i] = q
            D = 0.0
        } else {
            D = D + d
        }
    }
    return newPoints
}

func Centroid(points: [CGPoint]) -> CGPoint {
    var center = CGPointZero
    for point in points {
        center.x += point.x
        center.y += point.y
    }
    center.x /= CGFloat(points.count)
    center.y /= CGFloat(points.count)
    return center
}

func Distance(point1: CGPoint, point2: CGPoint) -> Float {
    let dx = Float(point2.x - point1.x)
    let dy = Float(point2.y - point1.y)
    return sqrtf(dx * dx + dy * dy)
}

func PathLength(points: [CGPoint]) -> Float {
    var d: Float = 0.0
    for i in 1..<points.count {
        d += Distance(points[i-1], points[i])
    }
    return d
}

func RotateToZero(points: [CGPoint]) -> [CGPoint] {
    let c = Centroid(points)
    let theta = Float(atan2(c.y - points[0].y, c.x - points[0].x))
    var newPoints: [CGPoint] = RotateBy(points, theta)
    return newPoints
}

func RotateBy(points: [CGPoint], theta: Float) -> [CGPoint] {
    let rotateTransform = CGAffineTransformMakeRotation(CGFloat(theta))
    var newPoints = [CGPoint]()
    for point in points {
        let newPoint = CGPointApplyAffineTransform(point, rotateTransform)
        newPoints.append(newPoint)
    }
    return newPoints
}

func BoundingBox(points: [CGPoint]) -> CGSize {
    var lowerLeft = CGPointZero, upperRight = CGPointZero
    for point in points {
        if point.x < lowerLeft.x {
            lowerLeft.x = point.x
        }
        if point.y < lowerLeft.y {
            lowerLeft.y = point.y
        }
        if point.x > upperRight.x {
            upperRight.x = point.x
        }
        if point.y > upperRight.y {
            upperRight.y = point.y
        }
    }
    return CGSizeMake(upperRight.x - lowerLeft.x, lowerLeft.y - upperRight.y)
}

func ScaleToSquare(points: [CGPoint], size: Int = 2) -> [CGPoint] {
    var b = BoundingBox(points)
    var q = CGPointZero
    var newPoints = [CGPoint]()
    for point in points {
        q.x = point.x * (CGFloat(size) / b.width)
        q.y = point.y * (CGFloat(size) / b.height)
        newPoints.append(q)
    }
    return newPoints
}

func TranslateTo(points: [CGPoint], k: CGPoint) -> [CGPoint] {
    var c = Centroid(points)
    var q = CGPointZero
    var newPoints = [CGPoint]()
    for point in points {
        q.x = point.x + k.x - c.x
        q.y = point.y + k.x - c.y
        newPoints.append(q)
    }
    return newPoints
}

func TranslateToOrigin(points: [CGPoint]) -> [CGPoint] {
    return TranslateTo(points, CGPointZero)
}

func Recognize(points: [CGPoint], templates: [String: [CGPoint]]) -> (name: String, score: Float) {
    var b = Float.infinity // best distance
    var n = "" // best template name
    for (name, template) in templates {
        var d = DistanceAtBestAngle(points, template)
        if d < b {
            b = d
            n = name
        }
    }
    var size: Float = 2
    var score = 1 - b / 0.5 * sqrtf(powf(size, 2) + powf(size, 2))
    return (n, score)
}

func DistanceAtBestAngle(points: [CGPoint], template: [CGPoint]) -> Float {
    var a = Float(-0.25 * M_PI) // theta A
    var b = -a // theta B
    var threshold: Float = 0.1 // theta delta
    let Phi = 1/2 * (-1.0 + sqrtf(5.0))
    var x1 = Phi * a + (1.0 - Phi) * b
    var f1 = DistanceAtAngle(points, template, x1)
    var x2 = (1.0 - Phi) * a + Phi * b
    var f2 = DistanceAtAngle(points, template, x2)
    while fabsf(Float(b - a)) > threshold {
        if f1 < f2 {
            b = x2
            x2 = x1
            f2 = f1
            x1 = Phi * a + (1.0 - Phi) * b
            f1 = DistanceAtAngle(points, template, x1)
        } else {
            a = x1
            x1 = x2
            f1 = f2
            x2 = (1.0 - Phi) * a + Phi * b
            f2 = DistanceAtAngle(points, template, x2)
        }
    }
    return min(f1, f2)
}

func DistanceAtAngle(points: [CGPoint], template: [CGPoint], theta: Float) -> Float {
    var newPoints = RotateBy(points, theta)
    var d = PathDistance(newPoints, template)
    return d
}

func PathDistance(A: [CGPoint], B: [CGPoint]) -> Float {
    var d: Float = 0.0
    for i in 0..<A.count {
        d += Distance(A[i], B[i])
    }
    return d / Float(A.count)
}
