//
//  SoundwaveView.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 18/01/2025.
//

// Inspiration: https://dribbble.com/shots/13475592-Soundwave

import SwiftUI
import Charts


public struct SoundwaveView: View {
    @ObservedObject var soundwaveData: SoundwaveData
    
    @State private var dataset1: [Float] = []
    @State private var dataset2: [Float] = []
    @State private var dataset3: [Float] = []
    @State private var dataset4: [Float] = []
    
    private func dampenEdges(_ values: [Float]) -> [Float] {
        let dampening = 4 // Number of values to dampen on each side
        return values.enumerated().map { index, value in
            if index < dampening {
                // Left side dampening
                return value * Float(index) / Float(dampening)
            } else if index >= values.count - dampening {
                // Right side dampening
                return value * Float(values.count - 1 - index) / Float(dampening)
            }
            return value
        }
    }
    
    public var body: some View {
        ZStack {
//            RoundedRectangle(cornerRadius: 8)
//                .fill(.black)
            
            VStack(spacing: 0) {
                ZStack {
                    WaveChartView(data: soundwaveData.magnitudes1, color: .purple.opacity(1))
                    WaveChartView(data: soundwaveData.magnitudes3, color: .blue.opacity(1))
                }
                
                ZStack {
                    WaveChartView(data: soundwaveData.magnitudes2, color: .purple.opacity(1))
                    WaveChartView(data: soundwaveData.magnitudes4, color: .blue.opacity(1))
//                    WaveChartView(data: dataset4, color: .purple.opacity(0.8))
                }
                .scaleEffect(x: 1, y: -1)
            }
//            .padding(.vertical, 6)
            
        }
        .onAppear {
            // Generate and process all datasets
            let rawData1 = (0..<10).map { _ in Float.random(in: -0.2...1) }
            dataset1 = dampenEdges(rawData1)
            
            let rawData2 = (0..<10).map { _ in Float.random(in: -0.2...1) }
            dataset2 = dampenEdges(rawData2)
            
            let rawData3 = (0..<12).map { _ in Float.random(in: -0.2...1) }
            dataset3 = dampenEdges(rawData3)
            
            let rawData4 = (0..<12).map { _ in Float.random(in: -0.2...1) }
            dataset4 = dampenEdges(rawData4)
        }
    }
}

struct WaveChartView: View {
    let data: [Float]
    let color: Color
    
    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                // Gradient area
                AreaMark(
                    x: .value("Index", index),
                    y: .value("Amplitude", Double(value))
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.5), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                // Solid line
                LineMark(
                    x: .value("Index", index),
                    y: .value("Amplitude", Double(value))
                )
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(color.opacity(0.7))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
    }
}
