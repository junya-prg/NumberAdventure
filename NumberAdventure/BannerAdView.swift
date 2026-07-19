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
        VStack(spacing: 2) {
            // 広告ラベル
            HStack {
                Text("広告")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            
            #if targetEnvironment(simulator)
            // シミュレータ時はプレースホルダーを表示して隙間を確認しやすくする
            HStack {
                Spacer()
                Text("広告プレースホルダー (実機で広告が表示されます)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .frame(height: 50)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            #else
            // 実機のみAdMob広告を表示
            BannerViewControllerRepresentable()
                .frame(height: GADAdSizeBanner.size.height)
                .background(Color.clear)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            #endif
        }
        .background(Color.black.opacity(0.3)) // 半透明の暗い背景
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
