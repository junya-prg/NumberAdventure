//
//  AdManager.swift
//  NumberAdventure
//
//  広告管理サービス
//  Google AdMobの初期化および子供向けブロックコントロール（COPPA/ファミリーポリシー準拠）の管理
//

import Foundation
import GoogleMobileAds
import os

private let logger = Logger(subsystem: "jp.junya.NumberAdventure", category: "AdManager")

/// 広告管理サービス
@MainActor
@Observable
final class AdManager {
    /// シングルトンインスタンス
    static let shared = AdManager()
    
    /// 広告の初期化完了フラグ
    private(set) var isInitialized = false
    
    // テストモード: 開発・テスト（デバッグ）ビルド時は自動的にテスト広告を使用し、リリースビルド時に本番用広告に切り替えます。
    #if DEBUG
    private let useTestAds = true
    #else
    private let useTestAds = false
    #endif
    
    /// バナー広告ユニットID
    var bannerAdUnitId: String {
        if useTestAds {
            // Googleの公式テストバナー広告ID
            return "ca-app-pub-3940256099942544/2934735716"
        } else {
            // 本番用バナー広告ID（すうじアドベンチャー バナー）
            return "ca-app-pub-2534039379765102/8769881346"
        }
    }
    
    private init() {}
    
    /// AdMobを初期化する
    func initialize() {
        guard !isInitialized else { return }
        
        // --- 子供向けブロックコントロール (COPPA / ファミリーポリシー準拠) ---
        let config = GADMobileAds.sharedInstance().requestConfiguration
        
        // 1. 児童向けコンテンツとしてマーク (tagForChildDirectedTreatment)
        config.tagForChildDirectedTreatment = true
        
        // 2. コンテンツレーティングの上限を「G（全年齢対象）」に制限
        config.maxAdContentRating = .general
        
        // 3. 同意年齢未満のユーザーとしてマーク
        config.tagForUnderAgeOfConsent = true
        
        // Google Mobile Ads SDKの初期化
        GADMobileAds.sharedInstance().start { [weak self] _ in
            DispatchQueue.main.async {
                self?.isInitialized = true
                logger.info("✅ AdMob初期化完了（子供向けブロックコントロール適用済）")
            }
        }
    }
}
