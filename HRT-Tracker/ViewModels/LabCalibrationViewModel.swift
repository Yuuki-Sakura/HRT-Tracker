import Foundation
import Combine
import HRTModels
import HRTPKEngine

@MainActor
final class LabCalibrationViewModel: ObservableObject {
    @Published var labResults: [LabResult] = []
    @Published var calibratedConcentrations: [Double] = []

    func updateCalibration(sim: SimulationResult?) {
        guard let sim = sim else {
            calibratedConcentrations = []
            return
        }
        calibratedConcentrations = LabCalibration.calibratedConcentration(sim: sim, labResults: labResults)
    }

    func addResult(_ result: LabResult) {
        labResults.append(result)
        labResults.sort { $0.timestamp < $1.timestamp }
    }

    func removeResult(_ result: LabResult) {
        labResults.removeAll { $0.id == result.id }
    }
}
