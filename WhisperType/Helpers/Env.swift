//
//  Env.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 03/03/2025.
//

func isDev() -> Bool {
    return isDebug()
}

func getEnv() -> String {
    return isDebug() ? "debug" : "production"
}

fileprivate func isDebug() -> Bool {
#if DEBUG
    return true
#else
    return false
#endif
}
