//
//  BannerAdView.swift
//  NumberAdventure
//
//  バナー広告コンポーネント
//  画面下部に固定配置する標準的なバナー広告
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: View {
    var body: some View {
        #if targetEnvironment(simulator)
        // シミュレータ上（スクリーンショット撮影時など）は広告を非表示にしてUIを綺麗に保つ
        EmptyView()
            .frame(height: 0)
        #else
        // 実機（本番配信）のみ広告を表示
        BannerViewControllerRepresentable()
            .frame(height: GADAdSizeBanner.size.height)
            .background(Color.clear)
        #endif
    }
}

private struct BannerViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        
        bannerView.adUnitID = AdManager.shared.bannerAdUnitId
        bannerView.rootViewController = viewController
        bannerView.load(GADRequest())
        
        viewController.view.addSubview(bannerView)
        
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: GADAdSizeBanner.size.width),
            bannerView.heightAnchor.constraint(equalToConstant: GADAdSizeBanner.size.height)
        ])
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
