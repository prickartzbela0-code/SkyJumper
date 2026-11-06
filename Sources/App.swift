import SwiftUI
import SpriteKit

@main
struct SkyJumperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBarHidden(true)
                .preferredColorScheme(.dark)
        }
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

// MARK: - Navigation

enum Screen { case menu, game, shop }

struct ContentView: View {
    @StateObject private var store = GameStore.shared
    @State private var screen: Screen = .menu
    @State private var scene: GameScene?
    @State private var result: RunResult?

    var body: some View {
        ZStack {
            switch screen {
            case .menu:
                MenuView(store: store, play: startGame, shop: { withAnimation(.easeInOut(duration: 0.25)) { screen = .shop } })
                    .transition(.opacity)
            case .shop:
                ShopView(store: store, back: { withAnimation(.easeInOut(duration: 0.25)) { screen = .menu } })
                    .transition(.move(edge: .trailing))
            case .game:
                if let scene {
                    GameView(scene: scene).ignoresSafeArea()
                }
                if let result {
                    GameOverView(result: result, again: startGame, menu: {
                        self.result = nil
                        self.scene = nil
                        withAnimation(.easeInOut(duration: 0.25)) { screen = .menu }
                    })
                    .transition(.opacity)
                }
            }
        }
    }

    private func startGame() {
        result = nil
        let s = GameScene(size: UIScreen.main.bounds.size)
        s.onGameOver = { score, coins in
            let r = GameStore.shared.finishRun(score: score, collected: coins)
            withAnimation(.easeOut(duration: 0.2)) { result = r }
        }
        scene = s
        screen = .game
    }
}

struct GameView: UIViewRepresentable {
    let scene: GameScene

    func makeUIView(context: Context) -> SKView {
        let v = SKView()
        v.isMultipleTouchEnabled = true
        v.ignoresSiblingOrder = true
        v.shouldCullNonVisibleNodes = true
        v.preferredFramesPerSecond = 60   // spart Akku auf 120-Hz-iPhones
        v.presentScene(scene)
        return v
    }

    func updateUIView(_ v: SKView, context: Context) {
        if v.scene !== scene { v.presentScene(scene) }
    }
}

// MARK: - Knöpfe

struct ChunkyButton: ButtonStyle {
    var color: Color
    var size: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 22).fill(color.gradient))
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(color.opacity(0.55))
                    .brightness(-0.25)
                    .offset(y: configuration.isPressed ? 2 : 7)
            )
            .offset(y: configuration.isPressed ? 5 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct CoinPill: View {
    let coins: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(uiImage: Art.coinImage).resizable().frame(width: 22, height: 22)
            Text("\(coins)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.25)))
    }
}

// MARK: - Menü

struct MenuView: View {
    @ObservedObject var store: GameStore
    var play: () -> Void
    var shop: () -> Void

    @State private var bob = false
    @State private var drift = false
    @State private var wobble = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1E6FD9), Color(hex: 0x6CC6FF), Color(hex: 0xC9F0FF)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            GeometryReader { geo in
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "cloud.fill")
                        .font(.system(size: CGFloat(50 + i * 14)))
                        .foregroundStyle(.white.opacity(0.75))
                        .position(x: geo.size.width * [0.15, 0.8, 0.35, 0.9, 0.1][i],
                                  y: geo.size.height * [0.12, 0.25, 0.55, 0.7, 0.85][i])
                        .offset(x: drift ? CGFloat(18 + i * 6) : -CGFloat(18 + i * 6))
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    CoinPill(coins: store.coins)
                }

                VStack(spacing: -14) {
                    Text("SKY")
                    Text("JUMPER")
                }
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xFFB000), Color(hex: 0xFF6B35)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: 0x7A2E00).opacity(0.6), radius: 0, x: 0, y: 6)
                .rotationEffect(.degrees(wobble ? -3 : 3))
                .scaleEffect(wobble ? 1.03 : 0.98)

                ZStack {
                    Ellipse()
                        .fill(.black.opacity(0.18))
                        .frame(width: bob ? 50 : 80, height: 12)
                        .offset(y: 82)
                    Image(uiImage: Art.platformImage(.normal))
                        .resizable()
                        .frame(width: 160, height: 44)
                        .offset(y: 100)
                    Image(uiImage: Art.characterPreview(store.character))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 128, height: 144)
                        .scaleEffect(x: bob ? 0.92 : 1.08, y: bob ? 1.1 : 0.92, anchor: .bottom)
                        .offset(y: bob ? -50 : 20)
                }
                .frame(height: 220)

                HStack(spacing: 12) {
                    statCard(icon: "trophy.fill", color: Color(hex: 0xFFD166), title: "HIGHSCORE", value: store.highScore)
                    statCard(icon: "person.fill", color: Color(hex: 0x7BED9F), title: "CHARAKTER", text: store.character.name)
                }

                Spacer(minLength: 4)

                Button(action: play) { Label("SPIELEN", systemImage: "play.fill") }
                    .buttonStyle(ChunkyButton(color: Color(hex: 0x2ECC71), size: 28))
                Button(action: shop) { Label("SHOP", systemImage: "cart.fill") }
                    .buttonStyle(ChunkyButton(color: Color(hex: 0xFF8C42)))

                Toggle(isOn: $store.swapControls) {
                    Label("Sprungtaste links", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .tint(Color(hex: 0x2ECC71))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(.black.opacity(0.2)))
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { drift = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { wobble = true }
        }
    }

    private func statCard(icon: String, color: Color, title: String, value: Int? = nil, text: String? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Text(title).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.75))
            Text(text ?? "\(value ?? 0)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.22)))
    }
}

// MARK: - Shop

struct ShopView: View {
    @ObservedObject var store: GameStore
    var back: () -> Void
    @State private var tab = 0

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x24164F), Color(hex: 0x6A3093)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.white.opacity(0.15)))
                    }
                    Spacer()
                    Text("SHOP")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    CoinPill(coins: store.coins)
                }

                Picker("", selection: $tab) {
                    Text("Charaktere").tag(0)
                    Text("Sprung-Effekte").tag(1)
                }
                .pickerStyle(.segmented)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: cols, spacing: 14) {
                        if tab == 0 {
                            ForEach(Catalog.characters) { c in
                                ShopCard(name: c.name, price: c.price,
                                         owned: store.owned.contains(c.id),
                                         equipped: store.characterID == c.id,
                                         affordable: store.coins >= c.price,
                                         preview: CharacterBob(image: Art.characterPreview(c), active: store.characterID == c.id)) {
                                    select(id: c.id, price: c.price) { store.characterID = c.id }
                                }
                            }
                        } else {
                            ForEach(Catalog.effects) { e in
                                ShopCard(name: e.name, price: e.price,
                                         owned: store.owned.contains(e.id),
                                         equipped: store.effectID == e.id,
                                         affordable: store.coins >= e.price,
                                         preview: EffectBadge(effect: e, active: store.effectID == e.id)) {
                                    select(id: e.id, price: e.price) { store.effectID = e.id }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                    .padding(.top, 4)
                }

                Text("Münzen sammelst du im Spiel – und für jede Höhe gibt's Bonus!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
    }

    private func select(id: String, price: Int, equip: () -> Void) {
        let haptic = UINotificationFeedbackGenerator()
        if store.owned.contains(id) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { equip() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if store.buy(id, price: price) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { equip() }
            haptic.notificationOccurred(.success)
        } else {
            haptic.notificationOccurred(.error)
        }
    }
}

struct CharacterBob: View {
    let image: UIImage
    let active: Bool
    @State private var up = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: 76, height: 86)
            .offset(y: active && up ? -8 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { up = true }
            }
    }
}

struct EffectBadge: View {
    let effect: JumpEffect
    let active: Bool
    @State private var turn = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: effect.colors.map { Color(uiColor: $0) } + [Color(uiColor: effect.colors[0])],
                                      center: .center))
                .frame(width: 78, height: 78)
                .rotationEffect(.degrees(active && turn ? 360 : 0))
                .shadow(color: Color(uiColor: effect.colors.last ?? .white).opacity(0.7), radius: active ? 12 : 4)
            Circle().fill(.black.opacity(0.25)).frame(width: 60, height: 60)
            Image(systemName: effect.symbol)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { turn = true }
        }
    }
}

struct ShopCard<Preview: View>: View {
    let name: String
    let price: Int
    let owned: Bool
    let equipped: Bool
    let affordable: Bool
    let preview: Preview
    let action: () -> Void
    @State private var shake: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            preview.frame(height: 96)
            Text(name)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Button {
                if !owned && !affordable { withAnimation(.linear(duration: 0.35)) { shake += 1 } }
                action()
            } label: {
                HStack(spacing: 5) {
                    if equipped {
                        Image(systemName: "checkmark.circle.fill")
                        Text("AKTIV")
                    } else if owned {
                        Text("WÄHLEN")
                    } else {
                        Image(uiImage: Art.coinImage).resizable().frame(width: 18, height: 18)
                        Text("\(price)")
                    }
                }
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(buttonColor))
            }
            .modifier(Shake(amount: shake))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(equipped ? 0.2 : 0.09)))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(equipped ? Color(hex: 0xFFD166) : .white.opacity(0.15), lineWidth: equipped ? 3 : 1)
        )
        .scaleEffect(equipped ? 1.02 : 1)
    }

    private var buttonColor: Color {
        if equipped { return Color(hex: 0x2ECC71) }
        if owned { return Color(hex: 0x3D8BFF) }
        return affordable ? Color(hex: 0xFF8C42) : Color.gray.opacity(0.5)
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}

// MARK: - Game Over

struct GameOverView: View {
    let result: RunResult
    var again: () -> Void
    var menu: () -> Void
    @State private var appear = false
    @State private var pulse = false
    @State private var shownScore = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                if result.newRecord {
                    Text("NEUER REKORD!")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xFFB000), Color(hex: 0xFF4FD8)],
                                                        startPoint: .leading, endPoint: .trailing))
                        .scaleEffect(pulse ? 1.12 : 0.94)
                        .rotationEffect(.degrees(pulse ? -3 : 3))
                } else {
                    Text("GAME OVER")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text("\(shownScore)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 5)

                Label("BEST \(result.best)", systemImage: "trophy.fill")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFFD166))

                HStack(spacing: 6) {
                    Image(uiImage: Art.coinImage).resizable().frame(width: 22, height: 22)
                    Text("+\(result.collected + result.bonus)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("(\(result.collected) gesammelt + \(result.bonus) Höhenbonus)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 8)

                Button(action: again) { Label("NOCHMAL", systemImage: "arrow.clockwise") }
                    .buttonStyle(ChunkyButton(color: Color(hex: 0x2ECC71)))
                Button(action: menu) { Label("MENÜ", systemImage: "house.fill") }
                    .buttonStyle(ChunkyButton(color: Color(hex: 0x3D8BFF), size: 20))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(colors: [Color(hex: 0x3A1C71), Color(hex: 0x6A3093)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.2), lineWidth: 2))
            .padding(26)
            .scaleEffect(appear ? 1 : 0.5)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { appear = true }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { pulse = true }
            countUp()
        }
    }

    /// Score zählt hoch statt einfach zu erscheinen
    private func countUp() {
        let steps = 20
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.03) {
                withAnimation(.easeOut(duration: 0.05)) { shownScore = result.score * i / steps }
            }
        }
    }
}
