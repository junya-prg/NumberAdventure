import Foundation
import MultipeerConnectivity
import Combine
import UIKit

// MARK: - ゲームタイプ定義
enum BattleGameMode: String, Codable, CaseIterable, Identifiable {
    case coopMakeTen = "coopMakeTen"          // あわせて10 (協力)
    case battleMultiples = "battleMultiples"  // ばいすうバスターズ (対戦)
    case battlePlaceValue = "battlePlaceValue"// 100のかべレース (対戦)
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .coopMakeTen: return "あわせて10！ (きょうりょく)"
        case .battleMultiples: return "ばいすうバスターズ (たいせん)"
        case .battlePlaceValue: return "くらいのかべ レース (たいせん)"
        }
    }
    
    var subtitle: String {
        switch self {
        case .coopMakeTen: return "ふたりで たして10になる すうじを ロックオン！"
        case .battleMultiples: return "お題の倍数を あいてより はやく撃ちぬけ！"
        case .battlePlaceValue: return "98→99→100… じゅんばんに はやく撃て！"
        }
    }
    
    var icon: String {
        switch self {
        case .coopMakeTen: return "plus.circle.fill"
        case .battleMultiples: return "multiply.circle.fill"
        case .battlePlaceValue: return "flag.checkered.circle.fill"
        }
    }
}

// MARK: - 通信イベント
enum BattleEvent: Codable {
    case ready(playerName: String)
    case gameStart(mode: BattleGameMode, ruleParam: Int, seed: UInt64, timeLimit: Double)
    case lockOn(targetNumber: Int, playerUUID: String, playerName: String)
    case unlock(targetNumber: Int, playerUUID: String)
    case targetHit(targetNumber: Int, playerUUID: String, playerName: String, points: Int)
    case pairSuccess(num1: Int, num2: Int, sum: Int, totalScore: Int)
    case gameFinished(winnerUUID: String?, winnerName: String, scoreA: Int, scoreB: Int)
    case leaveGame
}

// MARK: - P2P近接通信マネージャー
final class LocalBattleManager: NSObject, ObservableObject {
    static let shared = LocalBattleManager()
    
    // サービスタイプ: Info.plistの _num-adv._tcp に合わせる (最大15文字)
    private let serviceType = "num-adv"
    
    let myUUID = UUID().uuidString
    var myName: String {
        #if targetEnvironment(simulator)
        return "シミュレータ"
        #else
        return UIDevice.current.name.isEmpty ? "プレイヤー" : UIDevice.current.name
        #endif
    }
    
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    // UIバインド用
    @Published var isSearching = false
    @Published var isConnected = false
    @Published var isHost = false
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeerName: String = ""
    @Published var lastEvent: BattleEvent?
    
    // 接続状態
    @Published var connectionStateDescription: String = "たいき中"
    
    override init() {
        super.init()
        setupPeerAndSession()
    }
    
    private func setupPeerAndSession() {
        // 表示名
        let name = myName
        myPeerID = MCPeerID(displayName: name)
        
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["uuid": myUUID],
            serviceType: serviceType
        )
        advertiser.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
    }
    
    // MARK: - 探索開始 / 停止
    func startHosting() {
        stopAll()
        isHost = true
        isSearching = true
        connectionStateDescription = "おともだちを まっています..."
        advertiser.startAdvertisingPeer()
    }
    
    func startBrowsing() {
        stopAll()
        isHost = false
        isSearching = true
        connectionStateDescription = "ちかくのおともだちを さがしています..."
        browser.startBrowsingForPeers()
    }
    
    // 自動マッチング（ホストとブラウズの両方を開始し、見つかり次第接続）
    func startAutoPairing() {
        stopAll()
        isSearching = true
        connectionStateDescription = "ちかくの端末を さがしています..."
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }
    
    func stopAll() {
        isSearching = false
        discoveredPeers.removeAll()
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
    }
    
    func disconnect() {
        sendEvent(.leaveGame)
        session.disconnect()
        stopAll()
        isConnected = false
        connectedPeerName = ""
        connectionStateDescription = "せつだんしました"
    }
    
    // 相手に接続招待
    func invite(peer: MCPeerID) {
        connectionStateDescription = "\(peer.displayName) に せつぞく中..."
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    }
    
    // MARK: - イベント送信
    func sendEvent(_ event: BattleEvent) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(event)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[BattleManager] 送信失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCSessionDelegate
extension LocalBattleManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
                self.isSearching = false
                self.connectedPeerName = peerID.displayName
                self.connectionStateDescription = "\(peerID.displayName) と つながったよ！"
                print("[BattleManager] 接続完了: \(peerID.displayName)")
            case .connecting:
                self.connectionStateDescription = "\(peerID.displayName) と つないでいます..."
            case .notConnected:
                self.isConnected = false
                self.connectedPeerName = ""
                self.connectionStateDescription = "せつぞくが きれました"
                print("[BattleManager] 切断: \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let event = try JSONDecoder().decode(BattleEvent.self, from: data)
            DispatchQueue.main.async {
                self.lastEvent = event
            }
        } catch {
            print("[BattleManager] 受信パースエラー: \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension LocalBattleManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            // お子様が迷わないよう、近くの端末からの招待は自動受諾
            print("[BattleManager] 招待受信: \(peerID.displayName) -> 自動承認")
            invitationHandler(true, self.session)
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.connectionStateDescription = "アドバタイズ失敗: \(error.localizedDescription)"
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension LocalBattleManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
                print("[BattleManager] 端末発見: \(peerID.displayName)")
                
                // 自動ペアリング時: 最初に見つかった端末に自動招待
                if !self.isConnected && self.session.connectedPeers.isEmpty {
                    self.invite(peer: peerID)
                }
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.connectionStateDescription = "ブラウズ失敗: \(error.localizedDescription)"
        }
    }
}
