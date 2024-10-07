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
    
    static let shared = WebVTTParser()
    
    func parseVTT(_ vttContent: String) -> [Subtitle] {
        var subtitles: [Subtitle] = []
        let lines = vttContent.components(separatedBy: .newlines)
        var currentStartTime: String?
        var currentEndTime: String?
        var currentText: String = ""

        for line in lines {
            // 忽略可能的數字編號行（兩種格式兼容）
            if let _ = Int(line) {
                // 是數字的話跳過，因為編號行在某些格式存在
                continue
            }
            
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

extension WebVTTParser {
    // 讀取 VTT 檔案
    func loadAndParseSubtitles(from urlString: String, completion: @escaping ([Subtitle]) -> Void) {
        guard let url = URL(string: urlString) else { return }
        if url.scheme == "file" {
            // 離線播放，讀取本地字幕
            do {
                let data = try String(contentsOf: URL(string: urlString)!)
                let parser = WebVTTParser()
                completion(parser.parseVTT(data))
            } catch {
                print("Failed to load subtitles: \(error)")
            }
        } else {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load subtitles: \(error)")
                    return
                }

                guard let data = data, let content = String(data: data, encoding: .utf8) else { return }
                let parser = WebVTTParser()
                completion(parser.parseVTT(content))
            }.resume()
        }
    }
    
    // 依照播放進度更新字幕
    func updateSubtitles(for currentTime: TimeInterval, subtitles: [Subtitle]) -> String {
        let currentSubtitle = subtitles.first { currentTime >= $0.startTime && currentTime <= $0.endTime }
        return currentSubtitle?.text ?? ""
    }
}
