import Foundation
import CoreGraphics

public class OneDollerUnistrokeRecognizer {
    let n = 32 // number of sampling points
    var points = [CGPoint]()
    var templates = [String: [CGPoint]]()
    
    public func addPoint(point: CGPoint) {
        self.points.append(point)
    }
    
    public func reset() {
        self.points.removeAll(keepCapacity: false)
    }
    
    public func detect(completion: (name: String?, score: Float?) -> Void) {
        let result = Recognize(self.serialize(), self.templates)
        completion(name: result.name, score: result.score)
    }
    
    public func serialize() -> [CGPoint] {
        var resampledPoints = Resample(self.points, self.n)
        resampledPoints = RotateToZero(resampledPoints)
        resampledPoints = ScaleToSquare(resampledPoints)
        resampledPoints = TranslateToOrigin(resampledPoints)
        return resampledPoints
    }
    
    public func addTemplate(name: String, samples: [CGPoint]) {
        if let s = self.templates[name] {
            self.templates.updateValue(samples, forKey: name)
        } else {
            self.templates[name] = samples
        }
    }
}
