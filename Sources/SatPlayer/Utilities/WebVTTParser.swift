//
//  WebVTTParser.swift
//
//
//  Created by Wataru on 2024/7/23.
//

import Foundation

public struct Subtitle {
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    
    init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

class WebVTTParser {
    func parseVTT(_ vttContent: String) -> [Subtitle] {
        var subtitles: [Subtitle] = []
        let lines = vttContent.components(separatedBy: .newlines)
        var currentStartTime: String?
        var currentEndTime: String?
        var currentText: String = ""

        for line in lines {
            if line.contains("-->") {
                let times = line.components(separatedBy: " --> ")
                if times.count == 2 {
                    currentStartTime = times[0].trimmingCharacters(in: .whitespaces)
                    currentEndTime = times[1].trimmingCharacters(in: .whitespaces)
                }
            } else if line.isEmpty {
                if let startTimeStr = currentStartTime,
                   let startTime = parseTimeInterval(startTimeStr),
                   let endTimeStr = currentEndTime,
                   let endTime = parseTimeInterval(endTimeStr) {
                    subtitles.append(Subtitle(startTime: startTime, endTime: endTime, text: currentText.trimmingCharacters(in: .whitespaces)))
                }
                currentStartTime = nil
                currentEndTime = nil
                currentText = ""
            } else {
                currentText += line + "\n"
            }
        }

        // Handle the last subtitle block
        if let startTimeStr = currentStartTime,
           let startTime = parseTimeInterval(startTimeStr),
           let endTimeStr = currentEndTime,
           let endTime = parseTimeInterval(endTimeStr) {
            subtitles.append(Subtitle(startTime: startTime, endTime: endTime, text: currentText.trimmingCharacters(in: .whitespaces)))
        }

        return subtitles
    }
    
    private func parseTimeInterval(_ string: String) -> TimeInterval? {
        let components = string.components(separatedBy: ":")
        print("DEBUG: components.count: \(components.count)")
        if components.count == 2 {
            let minutes = Double(components[0]) ?? 0
            let secondsComponents = components[1].components(separatedBy: ".")
            guard secondsComponents.count == 2 else { return nil }
            
            let seconds = Double(secondsComponents[0]) ?? 0
            let milliseconds = Double(secondsComponents[1]) ?? 0
            
            return (minutes * 60) + seconds + (milliseconds / 1000)
        }
        if components.count == 3 {
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let secondsComponents = components[2].components(separatedBy: ".")
            guard secondsComponents.count == 2 else { return nil }
            
            let seconds = Double(secondsComponents[0]) ?? 0
            let milliseconds = Double(secondsComponents[1]) ?? 0
            
            return (hours * 3600) + (minutes * 60) + seconds + (milliseconds / 1000)
        }
        
        return nil
    }
}
