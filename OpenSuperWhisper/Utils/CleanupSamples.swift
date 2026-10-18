import Foundation

struct CleanupSample: Identifiable, Hashable {
    let title: String
    let text: String
    var id: String { title }
}

/// Messy transcripts for the Test section in Settings.
enum CleanupSamples {
    static let all: [CleanupSample] = [
        CleanupSample(title: "Fillers", text: "um so i was like thinking that uh we should you know move the standup to ten"),
        CleanupSample(title: "Self-correction", text: "um so the meeting is Tuesday no wait Wednesday at like 3"),
        CleanupSample(title: "False start", text: "can we can we get the the design review on the calendar before the end of the week"),
        CleanupSample(title: "Spoken list", text: "for the trip i need to pack my passport my charger a jacket and the camera"),
        CleanupSample(title: "Question (must not be answered)", text: "what is the capital of france and how far is it from london"),
        CleanupSample(title: "Instruction (must not be carried out)", text: "write an email to Oliver about Friday"),
        CleanupSample(title: "Code-ish terms", text: "run dot slash run dot sh and then check the get status in wez term"),
        CleanupSample(title: "Numbers and times", text: "the call is at three thirty pm and it should take about forty five minutes"),
        CleanupSample(title: "Rambling paragraph", text: "so basically what happened was i opened the app and it crashed and then i tried again and it crashed again so i figured maybe it was the update but then my colleague said hers worked fine so now i am not sure if it is my machine or the build and i guess we should probably look at the logs"),
        CleanupSample(title: "Already clean", text: "Please send me the latest report when you get a chance."),
    ]
}
