import AVFoundation

// Adapted from: https://stackoverflow.com/questions/12569015/writing-buffer-of-audio-samples-to-aac-file-using-extaudiofilewrite-for-ios
func writeAudioSamplesToAACFile(samples: [Float], sampleRate: Double, outputURL: URL) throws {
    // Create audio format descriptions
    var clientFormat = AudioStreamBasicDescription(
        mSampleRate: sampleRate,
        mFormatID: kAudioFormatMPEG4AAC,
        mFormatFlags: 0,
        mBytesPerPacket: 0,
        mFramesPerPacket: 1024,
        mBytesPerFrame: 0,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 0,
        mReserved: 0
    )
    
    var localFormat = AudioStreamBasicDescription(
        mSampleRate: sampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 32,
        mReserved: 0
    )
    
    // Create audio file
    var audioFile: ExtAudioFileRef?
    var status = ExtAudioFileCreateWithURL(
        outputURL as CFURL,
        kAudioFileM4AType,
        &clientFormat,
        nil,
        AudioFileFlags.eraseFile.rawValue,
        &audioFile
    )
    
    guard status == noErr, let audioFile = audioFile else {
        throw NSError(domain: "AudioConversion", code: Int(status),
                     userInfo: [NSLocalizedDescriptionKey: "Failed to create audio file"])
    }
    
    // Set client format
    status = ExtAudioFileSetProperty(
        audioFile,
        kExtAudioFileProperty_ClientDataFormat,
        UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
        &localFormat
    )
    
    guard status == noErr else {
        throw NSError(domain: "AudioConversion", code: Int(status),
                     userInfo: [NSLocalizedDescriptionKey: "Failed to set client format"])
    }
    
    // Prepare audio buffer
    var audioBuffer = AudioBuffer()
    audioBuffer.mNumberChannels = 1
    audioBuffer.mDataByteSize = UInt32(samples.count * MemoryLayout<Float>.size)
    audioBuffer.mData = UnsafeMutableRawPointer(mutating: samples)
    
    var bufferList = AudioBufferList()
    bufferList.mNumberBuffers = 1
    bufferList.mBuffers = audioBuffer
    
    // Write audio data
    status = ExtAudioFileWrite(
        audioFile,
        UInt32(samples.count),
        &bufferList
    )
    
    guard status == noErr else {
        throw NSError(domain: "AudioConversion", code: Int(status),
                     userInfo: [NSLocalizedDescriptionKey: "Failed to write audio data"])
    }
    
    // Close file
    ExtAudioFileDispose(audioFile)
}
