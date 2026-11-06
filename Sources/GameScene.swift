import SpriteKit
import UIKit

private final class Platform {
    let node: SKSpriteNode
    let kind: PlatformKind
    let halfW: CGFloat
    let topOffset: CGFloat
    var baseX: CGFloat = 0
    var range: CGFloat = 0
    var phase: CGFloat = 0
    var speed: CGFloat = 0
    var dx: CGFloat = 0
    var broken = false
    var breaking = false
    var spring: SKSpriteNode?
    var top: CGFloat { node.position.y + topOffset }

    init(node: SKSpriteNode, kind: PlatformKind, halfW: CGFloat) {
        self.node = node
        self.kind = kind
        self.halfW = halfW
        self.topOffset = kind == .spring ? 30 : 13
    }
}

private final class Item {
    enum Kind { case coin, rocket, magnet }
    let node: SKSpriteNode
    let kind: Kind
    var taken = false
    init(node: SKSpriteNode, kind: Kind) { self.node = node; self.kind = kind }
}

final class GameScene: SKScene {
    /// Wird am Ende aufgerufen: (Score, eingesammelte Münzen)
    var onGameOver: ((Int, Int) -> Void)?

    // Einstellungen aus dem Speicher
    private let skin = GameStore.shared.character
    private let effect = GameStore.shared.effect
    private let swapped = GameStore.shared.swapControls
    private let oldBest = GameStore.shared.highScore

    // Physik
    private let gravity: CGFloat = 2300
    private let maxRun: CGFloat = 340
    private let jumpPower: CGFloat = 920
    private let airJumpPower: CGFloat = 830
    private let springPower: CGFloat = 1750

    // Knoten
    private let world = SKNode()
    private let cam = SKCameraNode()
    private let hud = SKNode()
    private let player = SKNode()
    private let spin = SKNode()
    private let bodySprite = SKSpriteNode()
    private let eyes = SKSpriteNode(texture: Art.eyes)
    private var trail: SKEmitterNode?
    private var rocketPack: SKSpriteNode?
    private var rocketFlame: SKEmitterNode?
    private var magnetAura: SKSpriteNode?

    // Spielzustand
    private var didSetup = false
    private var insets = UIEdgeInsets.zero
    private var vel = CGVector.zero
    private var grounded = false
    private weak var groundPlatform: Platform?
    private var coyote: CGFloat = 0
    private var jumpBuffer: CGFloat = 0
    private var airJumps = 1
    private var canCut = false
    private var jumpHeld = false
    private var rocketTime: CGFloat = 0
    private var magnetTime: CGFloat = 0
    private var facing: CGFloat = 1
    private var platforms: [Platform] = []
    private var items: [Item] = []
    private var startY: CGFloat = 0
    private var nextY: CGFloat = 0
    private var maxY: CGFloat = 0
    private var score = 0
    private var coinsCollected = 0
    private var lastMilestone = 0
    private var recordShown = false
    private var camY: CGFloat = 0
    private var lastCamY: CGFloat = 0
    private var shakeAmt: CGFloat = 0
    private var dead = false
    private var gamePaused = false
    private var lastTime: TimeInterval = 0
    private var clock: CGFloat = 0

    // Eingabe
    private var touchMap: [UITouch: Int] = [:]   // 0 links, 1 rechts, 2 springen
    private var leftHeld = false
    private var rightHeld = false
    private var btnLeft: SKSpriteNode!
    private var btnRight: SKSpriteNode!
    private var btnJump: SKSpriteNode!
    private var btnPause: SKSpriteNode!
    private var pauseOverlay: SKNode?

    // HUD
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let scoreShadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let coinLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let bestLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let coinIcon = SKSpriteNode(texture: Art.coin)
    private var shownScore = -1
    private var shownCoins = -1

    // Hintergrund
    private let skyBase = SKSpriteNode()
    private let skyGrad = SKSpriteNode(texture: Art.vGradient)
    private let starLayer = SKNode()
    private let cloudLayer = SKNode()
    private var clouds: [SKSpriteNode] = []
    private var stars: [SKSpriteNode] = []
    private var lastBgH: CGFloat = -1000

    // Vibration
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNote = UINotificationFeedbackGenerator()

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Aufbau

    override func didMove(to view: SKView) {
        guard !didSetup else { return }
        didSetup = true
        let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        insets = window?.safeAreaInsets ?? .zero

        backgroundColor = UIColor(hex: 0x3FA9F5)
        addChild(world)
        addChild(cam)
        camera = cam
        camY = size.height / 2
        lastCamY = camY
        cam.position = CGPoint(x: size.width / 2, y: camY)
        hud.zPosition = 100
        cam.addChild(hud)

        buildBackground()
        buildStart()
        buildPlayer()
        buildHUD()
        buildControls()
        hapticLight.prepare()
        hapticMedium.prepare()
    }

    private func buildBackground() {
        skyBase.size = size
        skyBase.color = UIColor(hex: 0x3FA9F5)
        skyBase.zPosition = -100
        cam.addChild(skyBase)
        skyGrad.size = size
        skyGrad.colorBlendFactor = 1
        skyGrad.zPosition = -99
        cam.addChild(skyGrad)

        starLayer.zPosition = -98
        starLayer.alpha = 0
        cam.addChild(starLayer)
        for _ in 0..<45 {
            let s = SKSpriteNode(texture: Art.dot)
            let d = CGFloat.random(in: 4...9)
            s.size = CGSize(width: d, height: d)
            s.position = CGPoint(x: CGFloat.random(in: -size.width / 2...size.width / 2),
                                 y: CGFloat.random(in: -size.height / 2...size.height / 2))
            s.run(.repeatForever(.sequence([
                .wait(forDuration: 0.5, withRange: 1),
                .fadeAlpha(to: 0.25, duration: Double.random(in: 0.4...1.2)),
                .fadeAlpha(to: 1, duration: Double.random(in: 0.4...1.2))
            ])))
            starLayer.addChild(s)
            stars.append(s)
        }

        cloudLayer.zPosition = -97
        cam.addChild(cloudLayer)
        for _ in 0..<6 {
            let c = SKSpriteNode(texture: Art.cloud)
            c.setScale(CGFloat.random(in: 0.6...1.25))
            c.alpha = CGFloat.random(in: 0.45...0.85)
            c.position = CGPoint(x: CGFloat.random(in: -size.width / 2...size.width / 2),
                                 y: CGFloat.random(in: -size.height / 2...size.height / 2))
            cloudLayer.addChild(c)
            clouds.append(c)
        }
    }

    private func buildStart() {
        startY = insets.bottom + 190
        maxY = startY
        _ = makePlatform(kind: .normal, x: size.width / 2, y: startY - 13, width: size.width + 60)
        nextY = startY + 105
        generate()

        if oldBest > 0 {
            let y = startY + CGFloat(oldBest) * 10
            let line = SKSpriteNode(texture: Art.dashed)
            line.size = CGSize(width: size.width, height: 4)
            line.position = CGPoint(x: size.width / 2, y: y)
            line.color = UIColor(hex: 0xFFD166)
            line.colorBlendFactor = 1
            line.alpha = 0.8
            line.zPosition = 1
            world.addChild(line)
            let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            l.text = "BEST \(oldBest)"
            l.fontSize = 14
            l.fontColor = UIColor(hex: 0xFFD166)
            l.horizontalAlignmentMode = .left
            l.position = CGPoint(x: 12, y: y + 8)
            l.zPosition = 1
            world.addChild(l)
        }
    }

    private func buildPlayer() {
        player.position = CGPoint(x: size.width / 2, y: startY)
        player.zPosition = 10
        world.addChild(player)
        spin.position = CGPoint(x: 0, y: 24)
        player.addChild(spin)

        bodySprite.texture = Art.character(skin)
        bodySprite.size = CGSize(width: 64, height: 72)
        bodySprite.anchorPoint = CGPoint(x: 0.5, y: 8.0 / 72.0)
        bodySprite.position = CGPoint(x: 0, y: -24)
        spin.addChild(bodySprite)

        eyes.size = CGSize(width: 24, height: 13)
        eyes.position = CGPoint(x: 3, y: 30)
        eyes.zPosition = 1
        bodySprite.addChild(eyes)
        eyes.run(.repeatForever(.sequence([
            .wait(forDuration: 2.6, withRange: 2.4),
            .scaleY(to: 0.1, duration: 0.06),
            .scaleY(to: 1, duration: 0.08)
        ])))

        if effect.style != .dust {
            let e = SKEmitterNode()
            let starry = effect.style == .stars || effect.style == .rainbow
            e.particleTexture = starry ? Art.star : Art.dot
            e.particleBirthRate = 0
            e.particleLifetime = 0.5
            e.particleLifetimeRange = 0.2
            e.particleSpeed = 25
            e.particleSpeedRange = 20
            e.emissionAngleRange = .pi * 2
            e.particlePositionRange = CGVector(dx: 16, dy: 20)
            e.particleAlphaSpeed = -2
            e.particleScale = starry ? 0.4 : 0.55
            e.particleScaleRange = 0.2
            e.particleScaleSpeed = -0.7
            e.particleRotationSpeed = starry ? 4 : 0
            applyColors(e, effect.colors)
            e.particleBlendMode = .add
            e.zPosition = -1
            e.targetNode = world
            spin.addChild(e)
            trail = e
        }
    }

    private func buildHUD() {
        let topY = size.height / 2 - insets.top - 38

        scoreShadow.fontSize = 48
        scoreShadow.fontColor = UIColor.black.withAlphaComponent(0.3)
        scoreShadow.verticalAlignmentMode = .center
        scoreShadow.position = CGPoint(x: 2, y: topY - 6)
        hud.addChild(scoreShadow)
        scoreLabel.fontSize = 48
        scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: 0, y: topY - 3)
        hud.addChild(scoreLabel)

        bestLabel.fontSize = 14
        bestLabel.fontColor = UIColor.white.withAlphaComponent(0.85)
        bestLabel.verticalAlignmentMode = .center
        bestLabel.position = CGPoint(x: 0, y: topY - 36)
        bestLabel.text = "BEST \(oldBest)"
        hud.addChild(bestLabel)

        coinIcon.size = CGSize(width: 26, height: 26)
        coinIcon.position = CGPoint(x: -size.width / 2 + 30, y: topY)
        hud.addChild(coinIcon)
        coinLabel.fontSize = 22
        coinLabel.fontColor = .white
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.verticalAlignmentMode = .center
        coinLabel.position = CGPoint(x: -size.width / 2 + 48, y: topY)
        hud.addChild(coinLabel)

        btnPause = SKSpriteNode(texture: Art.button("pause.fill", radius: 22))
        btnPause.position = CGPoint(x: size.width / 2 - 34, y: topY)
        btnPause.alpha = 0.8
        hud.addChild(btnPause)
        updateHUD()
    }

    private func buildControls() {
        let by = -size.height / 2 + insets.bottom + 80
        var lx = -size.width / 2 + 64
        var rx = -size.width / 2 + 162
        var jx = size.width / 2 - 84
        if swapped {
            lx = size.width / 2 - 162
            rx = size.width / 2 - 64
            jx = -size.width / 2 + 84
        }
        btnLeft = SKSpriteNode(texture: Art.button("chevron.left", radius: 42))
        btnRight = SKSpriteNode(texture: Art.button("chevron.right", radius: 42))
        btnJump = SKSpriteNode(texture: Art.button("arrow.up", radius: 54))
        btnLeft.position = CGPoint(x: lx, y: by)
        btnRight.position = CGPoint(x: rx, y: by)
        btnJump.position = CGPoint(x: jx, y: by + 6)
        for b in [btnLeft!, btnRight!, btnJump!] {
            b.alpha = 0.75
            hud.addChild(b)
        }
    }

    // MARK: - Plattformen & Items

    private var difficulty: CGFloat { min(1, max(0, (nextY - startY) / 25000)) }

    private func makePlatform(kind: PlatformKind, x: CGFloat, y: CGFloat, width: CGFloat) -> Platform {
        let n = SKSpriteNode(texture: Art.platform(kind))
        n.size = CGSize(width: 110, height: 30)
        n.centerRect = CGRect(x: 0.2, y: 0, width: 0.6, height: 1)
        n.xScale = width / 110
        n.position = CGPoint(x: x, y: y)
        n.zPosition = 2
        world.addChild(n)
        let pl = Platform(node: n, kind: kind, halfW: width / 2)
        if kind == .spring {
            let s = SKSpriteNode(texture: Art.spring)
            s.size = CGSize(width: 30, height: 26)
            s.anchorPoint = CGPoint(x: 0.5, y: 0)
            s.position = CGPoint(x: x, y: y + 9)
            s.zPosition = 3
            world.addChild(s)
            pl.spring = s
        }
        platforms.append(pl)
        return pl
    }

    private func addItem(_ kind: Item.Kind, at p: CGPoint) {
        let n: SKSpriteNode
        switch kind {
        case .coin:
            n = SKSpriteNode(texture: Art.coin)
            n.size = CGSize(width: 26, height: 26)
            n.run(.repeatForever(.sequence([.scaleX(to: 0.15, duration: 0.35), .scaleX(to: 1, duration: 0.35)])))
        case .rocket, .magnet:
            n = SKSpriteNode(texture: kind == .rocket ? Art.rocketItem : Art.magnet)
            n.size = CGSize(width: 44, height: 44)
            n.run(.repeatForever(.sequence([ease(.moveBy(x: 0, y: 8, duration: 0.6)), ease(.moveBy(x: 0, y: -8, duration: 0.6))])))
        }
        n.position = p
        n.zPosition = 6
        world.addChild(n)
        items.append(Item(node: n, kind: kind))
    }

    private func spawnRow(at y: CGFloat) {
        let diff = difficulty
        let h = y - startY
        var kind = PlatformKind.normal
        if h > 500 {
            let r = CGFloat.random(in: 0..<1)
            let pm = 0.08 + 0.30 * diff
            let pb = 0.04 + 0.18 * diff
            if r < 0.06 { kind = .spring }
            else if r < 0.06 + pm { kind = .moving }
            else if r < 0.06 + pm + pb { kind = .breaking }
        }
        let width: CGFloat = kind == .spring ? 80 : CGFloat.random(in: (84 - 22 * diff)...(112 - 24 * diff))
        let w = size.width
        let x = CGFloat.random(in: (width / 2 + 8)...(w - width / 2 - 8))
        let pl = makePlatform(kind: kind, x: x, y: y - 13, width: width)

        if kind == .moving {
            pl.range = CGFloat.random(in: 40...max(41, w / 2 - width / 2 - 14))
            let lo = width / 2 + pl.range + 8
            let hi = w - lo
            pl.baseX = lo < hi ? CGFloat.random(in: lo...hi) : w / 2
            pl.phase = CGFloat.random(in: 0...(.pi * 2))
            pl.speed = CGFloat.random(in: 1.1...1.9) * (1 + diff * 0.6)
            pl.node.position.x = pl.baseX + sin(pl.phase) * pl.range
        }

        if kind == .normal {
            let r = CGFloat.random(in: 0..<1)
            let top = y
            if h > 1800 && r < 0.03 {
                addItem(.rocket, at: CGPoint(x: x, y: top + 34))
            } else if h > 1000 && r < 0.06 {
                addItem(.magnet, at: CGPoint(x: x, y: top + 34))
            } else if r < 0.45 {
                addItem(.coin, at: CGPoint(x: x, y: top + 26))
                if r < 0.15 && width > 80 {
                    addItem(.coin, at: CGPoint(x: x - 26, y: top + 26))
                    addItem(.coin, at: CGPoint(x: x + 26, y: top + 26))
                }
            }
        }

        // Münzbogen in der Luft
        if h > 300 && CGFloat.random(in: 0..<1) < 0.1 {
            let cx = CGFloat.random(in: 70...(w - 70))
            for i in 0..<5 {
                let f = CGFloat(i) / 4
                addItem(.coin, at: CGPoint(x: cx - 56 + 112 * f, y: y + 60 + sin(f * .pi) * 40))
            }
        }
    }

    private func generate() {
        while nextY < camY + size.height * 0.75 {
            spawnRow(at: nextY)
            let d = difficulty
            nextY += CGFloat.random(in: (62 + 40 * d)...(112 + 58 * d))
        }
    }

    private func cleanup() {
        let limit = camY - size.height / 2 - 140
        platforms.removeAll { pl in
            guard pl.node.position.y < limit else { return false }
            pl.node.removeFromParent()
            pl.spring?.removeFromParent()
            return true
        }
        items.removeAll { it in
            if it.taken { return true }
            guard it.node.position.y < limit else { return false }
            it.node.removeFromParent()
            return true
        }
    }

    // MARK: - Spielschleife

    override func update(_ currentTime: TimeInterval) {
        let raw = lastTime == 0 ? 1.0 / 60 : currentTime - lastTime
        lastTime = currentTime
        guard !gamePaused else { return }
        let dt = CGFloat(min(max(raw, 0), 1.0 / 30))
        clock += dt
        if dead { updateCamera(dt); return }

        updatePlatforms(dt)
        updatePlayer(dt)
        if dead { return }
        updateItems(dt)
        updateCamera(dt)
        generate()
        cleanup()
        updateBackground()
        updateHUD()
    }

    private func updatePlatforms(_ dt: CGFloat) {
        for p in platforms where p.kind == .moving && !p.broken {
            p.phase += p.speed * dt
            let nx = p.baseX + sin(p.phase) * p.range
            p.dx = nx - p.node.position.x
            p.node.position.x = nx
        }
    }

    private func updatePlayer(_ dt: CGFloat) {
        let dir: CGFloat = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
        if dir != 0 {
            vel.dx += dir * (grounded ? 3000 : 2400) * dt
            vel.dx = max(-maxRun, min(maxRun, vel.dx))
            if facing != dir {
                facing = dir
                spin.removeAction(forKey: "turn")
                spin.run(.scaleX(to: dir, duration: 0.08), withKey: "turn")
            }
        } else {
            let fr: CGFloat = (grounded ? 3200 : 700) * dt
            vel.dx = abs(vel.dx) <= fr ? 0 : vel.dx - fr * (vel.dx > 0 ? 1 : -1)
        }
        bodySprite.zRotation = -(vel.dx / maxRun) * 0.14 * facing

        jumpBuffer -= dt
        coyote -= dt

        if magnetTime > 0 {
            magnetTime -= dt
            if let a = magnetAura, magnetTime < 2 { a.alpha = 0.3 + 0.3 * sin(clock * 22) }
            if magnetTime <= 0 { endMagnet() }
        }

        if rocketTime > 0 {
            rocketTime -= dt
            vel.dy = 1250
            if rocketTime <= 0 { endRocket() }
        } else {
            vel.dy = max(vel.dy - gravity * dt, -1500)
        }

        if jumpBuffer > 0 && rocketTime <= 0 {
            if grounded || coyote > 0 {
                jump(air: false)
            } else if airJumps > 0 {
                airJumps -= 1
                jump(air: true)
            }
        }

        if grounded, let gp = groundPlatform { player.position.x += gp.dx }

        let oldY = player.position.y
        var p = player.position
        p.x += vel.dx * dt
        p.y += vel.dy * dt
        let m: CGFloat = 18
        if p.x < -m { p.x += size.width + m * 2 } else if p.x > size.width + m { p.x -= size.width + m * 2 }

        var landed: Platform?
        if vel.dy <= 0 && rocketTime <= 0 {
            var bestTop = -CGFloat.greatestFiniteMagnitude
            for pl in platforms where !pl.broken {
                let top = pl.top
                if oldY >= top - 2, p.y <= top, abs(p.x - pl.node.position.x) < pl.halfW + 11, top > bestTop {
                    landed = pl
                    bestTop = top
                }
            }
        }

        if let pl = landed {
            p.y = pl.top
            let impact = -vel.dy
            player.position = p
            if pl.kind == .spring {
                bounce(on: pl)
            } else {
                vel.dy = 0
                if !grounded { land(on: pl, impact: impact) }
                grounded = true
                groundPlatform = pl
                airJumps = 1
            }
        } else {
            if grounded {
                grounded = false
                groundPlatform = nil
                coyote = 0.1
            }
            player.position = p
        }

        maxY = max(maxY, player.position.y)
        score = Int((maxY - startY) / 10)
        trail?.particleBirthRate = grounded ? 0 : 55

        if player.position.y < camY - size.height / 2 - 40 { die() }
    }

    private func updateItems(_ dt: CGFloat) {
        let c = CGPoint(x: player.position.x, y: player.position.y + 24)
        for it in items where !it.taken {
            var pos = it.node.position
            if it.kind == .coin && magnetTime > 0 {
                let dx = c.x - pos.x, dy = c.y - pos.y
                let d = hypot(dx, dy)
                if d < 240 && d > 1 {
                    let s = min(d, 750 * dt)
                    pos.x += dx / d * s
                    pos.y += dy / d * s
                    it.node.position = pos
                }
            }
            if abs(c.x - pos.x) < 30 && abs(c.y - pos.y) < 38 { collect(it) }
        }
    }

    private func updateCamera(_ dt: CGFloat) {
        if !dead {
            let target = player.position.y + size.height * 0.08
            if target > camY {
                let k: CGFloat = rocketTime > 0 ? 12 : 7
                camY += (target - camY) * min(1, dt * k)
            }
        }
        shakeAmt = max(0, shakeAmt - dt * 40)
        let ox = shakeAmt > 0 ? CGFloat.random(in: -shakeAmt...shakeAmt) : 0
        let oy = shakeAmt > 0 ? CGFloat.random(in: -shakeAmt...shakeAmt) : 0
        cam.position = CGPoint(x: size.width / 2 + ox, y: camY + oy)

        // Parallax
        let delta = camY - lastCamY
        lastCamY = camY
        guard delta != 0 else { return }
        let h = size.height, w = size.width
        for c in clouds {
            c.position.y -= delta * 0.4
            if c.position.y < -h / 2 - 70 {
                c.position.y += h + 140
                c.position.x = CGFloat.random(in: -w / 2...w / 2)
            }
        }
        for s in stars {
            s.position.y -= delta * 0.06
            if s.position.y < -h / 2 - 5 {
                s.position.y += h + 10
                s.position.x = CGFloat.random(in: -w / 2...w / 2)
            }
        }
    }

    private func updateBackground() {
        let h = max(0, camY - size.height / 2 - startY + 200)
        guard abs(h - lastBgH) > 6 else { return }
        lastBgH = h
        let stops: [(CGFloat, UInt32, UInt32)] = [
            (0, 0x3FA9F5, 0xBDE9FF),
            (3000, 0xFF6F61, 0xFFC371),
            (7000, 0x2D1B69, 0xB0417F),
            (12000, 0x05030F, 0x1A1450)
        ]
        var i = 0
        while i < stops.count - 2 && h > stops[i + 1].0 { i += 1 }
        let a = stops[i], b = stops[i + 1]
        let f = max(0, min(1, (h - a.0) / (b.0 - a.0)))
        skyBase.color = UIColor(hex: a.1).mix(UIColor(hex: b.1), f)
        skyGrad.color = UIColor(hex: a.2).mix(UIColor(hex: b.2), f)
        starLayer.alpha = max(0, min(1, (h - 5000) / 4000))
        cloudLayer.alpha = 1 - max(0, min(0.85, (h - 7500) / 3000))
    }

    private func updateHUD() {
        if score != shownScore {
            shownScore = score
            scoreLabel.text = "\(score)"
            scoreShadow.text = scoreLabel.text
            if score > 0 && score % 50 == 0 { pop(scoreLabel, 1.25) }
            let m = score / 250
            if m > lastMilestone {
                lastMilestone = m
                banner("\(m * 250)!", color: .white)
                burst(CGPoint(x: player.position.x, y: player.position.y + 24), tex: Art.star,
                      colors: Catalog.effects[5].colors, count: 30, speed: 260, angle: 0, range: .pi * 2, life: 0.9, scale: 0.5)
            }
            if oldBest > 0 && !recordShown && score > oldBest {
                recordShown = true
                bestLabel.fontColor = UIColor(hex: 0xFFD166)
                banner("NEUER REKORD!", color: UIColor(hex: 0xFFD166))
                hapticNote.notificationOccurred(.success)
            }
            if score > oldBest { bestLabel.text = "BEST \(score)" }
        }
        if coinsCollected != shownCoins {
            shownCoins = coinsCollected
            coinLabel.text = "\(coinsCollected)"
        }
    }

    // MARK: - Aktionen

    private func ease(_ a: SKAction, _ mode: SKActionTimingMode = .easeInEaseOut) -> SKAction {
        a.timingMode = mode
        return a
    }

    private func pop(_ n: SKNode, _ s: CGFloat) {
        n.removeAction(forKey: "pop")
        n.run(.sequence([ease(.scale(to: s, duration: 0.07), .easeOut), ease(.scale(to: 1, duration: 0.18))]), withKey: "pop")
    }

    private func squash(x: CGFloat, y: CGFloat) {
        bodySprite.removeAction(forKey: "squash")
        bodySprite.xScale = x
        bodySprite.yScale = y
        bodySprite.run(ease(.scaleX(to: 1, y: 1, duration: 0.22), .easeOut), withKey: "squash")
    }

    private func flip() {
        spin.removeAction(forKey: "flip")
        spin.zRotation = 0
        spin.run(.sequence([ease(.rotate(byAngle: -.pi * 2 * facing, duration: 0.4), .easeOut),
                            .run { [weak self] in self?.spin.zRotation = 0 }]), withKey: "flip")
    }

    private func jump(air: Bool) {
        jumpBuffer = 0
        coyote = 0
        vel.dy = air ? airJumpPower : jumpPower
        grounded = false
        groundPlatform = nil
        canCut = jumpHeld
        squash(x: 0.78, y: 1.28)
        if air { flip() }
        jumpFX(at: player.position, big: !air)
        hapticLight.impactOccurred(intensity: air ? 0.6 : 0.9)
    }

    private func bounce(on pl: Platform) {
        vel.dy = springPower
        grounded = false
        groundPlatform = nil
        airJumps = 1
        canCut = false
        pl.spring?.removeAllActions()
        pl.spring?.run(.sequence([.scaleY(to: 0.45, duration: 0.05), .scaleY(to: 1.6, duration: 0.08), ease(.scaleY(to: 1, duration: 0.2))]))
        squash(x: 0.7, y: 1.4)
        flip()
        jumpFX(at: player.position, big: true)
        ring(at: player.position, color: UIColor(hex: 0xFF6FB5))
        shakeAmt = 7
        hapticMedium.impactOccurred()
    }

    private func land(on pl: Platform, impact: CGFloat) {
        let k = min(1, impact / 1400)
        squash(x: 1 + 0.3 * k, y: 1 - 0.28 * k)
        burst(player.position, tex: Art.dot, colors: [UIColor.white.withAlphaComponent(0.9)], count: 6 + Int(8 * k),
              speed: 70, angle: .pi / 2, range: .pi * 0.9, life: 0.35, scale: 0.5, gravity: -150, add: false)
        if impact > 1300 { shakeAmt = max(shakeAmt, 4) }
        if pl.kind == .breaking && !pl.breaking { startBreaking(pl) }
    }

    private func startBreaking(_ pl: Platform) {
        pl.breaking = true
        let wiggle = SKAction.sequence([.moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: -6, y: 0, duration: 0.08), .moveBy(x: 3, y: 0, duration: 0.04)])
        pl.node.run(.sequence([
            .repeat(wiggle, count: 3),
            .run { [weak self, weak pl] in
                guard let self, let pl else { return }
                pl.broken = true
                self.burst(pl.node.position, tex: Art.dot, colors: [UIColor(hex: 0xEAD2A2), UIColor(hex: 0x8D6E63)], count: 16,
                           speed: 120, angle: -.pi / 2, range: .pi, life: 0.6, scale: 0.6, gravity: -500, add: false)
            },
            .group([ease(.moveBy(x: 0, y: -280, duration: 0.6), .easeIn), .fadeOut(withDuration: 0.6), .rotate(byAngle: 0.5, duration: 0.6)])
        ]))
    }

    private func collect(_ it: Item) {
        it.taken = true
        let pos = it.node.position
        switch it.kind {
        case .coin:
            coinsCollected += 1
            pop(coinIcon, 1.4)
            burst(pos, tex: Art.star, colors: [UIColor(hex: 0xFFF3B0), UIColor(hex: 0xFFC300)], count: 8,
                  speed: 110, angle: 0, range: .pi * 2, life: 0.4, scale: 0.4)
            floatText("+1", at: pos, color: UIColor(hex: 0xFFE066))
        case .rocket:
            startRocket()
            banner("RAKETE!", color: UIColor(hex: 0xFF9F1C))
        case .magnet:
            startMagnet()
            banner("MAGNET!", color: UIColor(hex: 0x4FE3FF))
        }
        it.node.removeAllActions()
        it.node.run(.sequence([.group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

    private func startRocket() {
        rocketTime = 2.4
        grounded = false
        groundPlatform = nil
        airJumps = 1
        canCut = false
        shakeAmt = 5
        hapticMedium.impactOccurred()
        if rocketPack == nil {
            let pack = SKSpriteNode(texture: Art.rocketPack)
            pack.size = CGSize(width: 40, height: 40)
            pack.position = CGPoint(x: -15, y: 2)
            pack.zRotation = 0.15
            pack.zPosition = -2
            spin.addChild(pack)
            rocketPack = pack

            let f = SKEmitterNode()
            f.particleTexture = Art.dot
            f.particleBirthRate = 0
            f.particleLifetime = 0.35
            f.particleLifetimeRange = 0.15
            f.emissionAngle = -.pi / 2
            f.emissionAngleRange = 0.35
            f.particleSpeed = 320
            f.particleSpeedRange = 80
            f.particleAlphaSpeed = -2.6
            f.particleScale = 0.9
            f.particleScaleSpeed = -2
            applyColors(f, [UIColor(hex: 0xFFF3B0), UIColor(hex: 0xFFB000), UIColor(hex: 0xFF3D00), UIColor(hex: 0x555555)])
            f.particleBlendMode = .add
            f.position = CGPoint(x: -15, y: -18)
            f.zPosition = -3
            f.targetNode = world
            spin.addChild(f)
            rocketFlame = f
        }
        rocketPack?.alpha = 1
        rocketFlame?.particleBirthRate = 260
    }

    private func endRocket() {
        rocketTime = 0
        vel.dy = 650
        rocketFlame?.particleBirthRate = 0
        rocketPack?.run(.fadeOut(withDuration: 0.3))
    }

    private func startMagnet() {
        magnetTime = 9
        hapticMedium.impactOccurred()
        if magnetAura == nil {
            let a = SKSpriteNode(texture: Art.ring)
            a.size = CGSize(width: 96, height: 96)
            a.color = UIColor(hex: 0x4FE3FF)
            a.colorBlendFactor = 1
            a.blendMode = .add
            a.position = CGPoint(x: 0, y: 24)
            a.zPosition = -4
            a.run(.repeatForever(.sequence([ease(.scale(to: 1.15, duration: 0.5)), ease(.scale(to: 0.95, duration: 0.5))])))
            player.addChild(a)
            magnetAura = a
        }
        magnetAura?.alpha = 0.55
    }

    private func endMagnet() {
        magnetTime = 0
        magnetAura?.removeFromParent()
        magnetAura = nil
    }

    private func die() {
        guard !dead else { return }
        dead = true
        touchMap.removeAll()
        leftHeld = false
        rightHeld = false
        trail?.particleBirthRate = 0
        rocketFlame?.particleBirthRate = 0
        hapticNote.notificationOccurred(.error)
        shakeAmt = 12
        flashScreen(UIColor(hex: 0xFF3B6B), alpha: 0.35)
        bodySprite.removeAllActions()
        player.run(.sequence([
            ease(.moveBy(x: 0, y: 70, duration: 0.25), .easeOut),
            .group([ease(.moveBy(x: 0, y: -800, duration: 0.8), .easeIn), .rotate(byAngle: 7, duration: 0.8)])
        ]))
        let finalScore = score
        let coins = coinsCollected
        run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in self?.onGameOver?(finalScore, coins) }]))
    }

    // MARK: - Effekte

    private func applyColors(_ e: SKEmitterNode, _ colors: [UIColor]) {
        e.particleColorBlendFactor = 1
        if colors.count == 1 {
            e.particleColor = colors[0]
            e.particleColorSequence = nil
        } else {
            let times = (0..<colors.count).map { NSNumber(value: Double($0) / Double(colors.count - 1)) }
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: colors, times: times)
        }
    }

    private func burst(_ pos: CGPoint, tex: SKTexture, colors: [UIColor], count: Int, speed: CGFloat,
                       angle: CGFloat, range: CGFloat, life: CGFloat, scale: CGFloat,
                       gravity: CGFloat = 0, add: Bool = true) {
        let e = SKEmitterNode()
        e.particleTexture = tex
        e.numParticlesToEmit = count
        e.particleBirthRate = CGFloat(count) * 40
        e.particleLifetime = life
        e.particleLifetimeRange = life * 0.4
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.5
        e.emissionAngle = angle
        e.emissionAngleRange = range
        e.particleAlphaSpeed = -1 / life
        e.particleScale = scale
        e.particleScaleRange = scale * 0.5
        e.particleScaleSpeed = -scale / life * 0.8
        e.particleRotationSpeed = tex == Art.star ? 5 : 0
        e.yAcceleration = gravity
        applyColors(e, colors)
        e.particleBlendMode = add ? .add : .alpha
        e.position = pos
        e.zPosition = 5
        e.targetNode = world
        world.addChild(e)
        e.run(.sequence([.wait(forDuration: Double(life) * 1.6 + 0.1), .removeFromParent()]))
    }

    private func ring(at p: CGPoint, color: UIColor) {
        let r = SKSpriteNode(texture: Art.ring)
        r.size = CGSize(width: 64, height: 64)
        r.color = color
        r.colorBlendFactor = 1
        r.blendMode = .add
        r.position = p
        r.zPosition = 4
        r.xScale = 0.3
        r.yScale = 0.1
        world.addChild(r)
        r.run(.sequence([.group([ease(.scaleX(to: 1.7, y: 0.55, duration: 0.32), .easeOut), .fadeOut(withDuration: 0.32)]), .removeFromParent()]))
    }

    private func jumpFX(at p: CGPoint, big: Bool) {
        let c = effect.colors
        let k: CGFloat = big ? 1 : 0.65
        switch effect.style {
        case .dust:
            burst(p, tex: Art.dot, colors: c, count: Int(14 * k), speed: 90, angle: -.pi / 2, range: .pi,
                  life: 0.45, scale: 0.7, gravity: 80, add: false)
        case .sparks:
            burst(p, tex: Art.dot, colors: c, count: Int(24 * k), speed: 280, angle: -.pi / 2, range: .pi * 1.2,
                  life: 0.5, scale: 0.35, gravity: -700)
        case .fire:
            burst(p, tex: Art.dot, colors: c, count: Int(32 * k), speed: 150, angle: -.pi / 2, range: 1.4,
                  life: 0.6, scale: 0.8, gravity: 420)
        case .stars:
            burst(p, tex: Art.star, colors: c, count: Int(18 * k), speed: 210, angle: 0, range: .pi * 2,
                  life: 0.8, scale: 0.55)
        case .lightning:
            burst(p, tex: Art.dot, colors: c, count: Int(22 * k), speed: 400, angle: 0, range: .pi * 2,
                  life: 0.3, scale: 0.4)
            for side in [-1.0, 1.0] as [CGFloat] {
                let b = SKSpriteNode(texture: Art.bolt)
                b.size = CGSize(width: 18, height: 30)
                b.color = c[1]
                b.colorBlendFactor = 1
                b.blendMode = .add
                b.position = CGPoint(x: p.x + side * 22, y: p.y + 6)
                b.zRotation = side * 0.5
                b.zPosition = 5
                world.addChild(b)
                b.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
            }
            if big { flashScreen(c[1], alpha: 0.18) }
        case .rainbow:
            burst(p, tex: Art.star, colors: c, count: Int(34 * k), speed: 240, angle: 0, range: .pi * 2,
                  life: 0.85, scale: 0.5)
        }
        if effect.style != .dust && big { ring(at: p, color: c.last ?? .white) }
    }

    private func flashScreen(_ color: UIColor, alpha: CGFloat) {
        let f = SKSpriteNode(color: color, size: size)
        f.alpha = alpha
        f.zPosition = 150
        f.blendMode = .add
        hud.addChild(f)
        f.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func floatText(_ text: String, at p: CGPoint, color: UIColor) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 18
        l.fontColor = color
        l.position = p
        l.zPosition = 7
        world.addChild(l)
        l.run(.sequence([.group([ease(.moveBy(x: 0, y: 40, duration: 0.5), .easeOut), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    private func banner(_ text: String, color: UIColor) {
        let n = SKNode()
        n.position = CGPoint(x: 0, y: size.height * 0.16)
        n.zPosition = 120
        let sh = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        sh.text = text
        sh.fontSize = 40
        sh.fontColor = UIColor.black.withAlphaComponent(0.35)
        sh.verticalAlignmentMode = .center
        sh.position = CGPoint(x: 3, y: -4)
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 40
        l.fontColor = color
        l.verticalAlignmentMode = .center
        n.addChild(sh)
        n.addChild(l)
        n.setScale(0.2)
        n.alpha = 0
        hud.addChild(n)
        n.run(.sequence([
            .group([.fadeIn(withDuration: 0.12), ease(.scale(to: 1.2, duration: 0.18), .easeOut)]),
            ease(.scale(to: 1, duration: 0.12)),
            .wait(forDuration: 0.7),
            .group([.fadeOut(withDuration: 0.3), .moveBy(x: 0, y: 40, duration: 0.3)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Pause

    private func togglePause() {
        guard !dead else { return }
        gamePaused.toggle()
        world.isPaused = gamePaused
        touchMap.removeAll()
        refreshButtons()
        if gamePaused {
            let o = SKNode()
            o.zPosition = 200
            let bg = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.5), size: size)
            o.addChild(bg)
            let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            l.text = "PAUSE"
            l.fontSize = 52
            l.verticalAlignmentMode = .center
            o.addChild(l)
            let s = SKLabelNode(fontNamed: "AvenirNext-Bold")
            s.text = "Tippe oben rechts zum Weiterspielen"
            s.fontSize = 15
            s.fontColor = UIColor.white.withAlphaComponent(0.8)
            s.position = CGPoint(x: 0, y: -46)
            o.addChild(s)
            hud.addChild(o)
            pauseOverlay = o
            btnPause.texture = Art.button("play.fill", radius: 22)
            btnPause.zPosition = 210
        } else {
            pauseOverlay?.removeFromParent()
            pauseOverlay = nil
            btnPause.texture = Art.button("pause.fill", radius: 22)
        }
    }

    // MARK: - Touch-Steuerung (Multitouch)

    private func buttonID(at p: CGPoint) -> Int? {
        if hypot(p.x - btnPause.position.x, p.y - btnPause.position.y) < 36 { return 3 }
        if hypot(p.x - btnJump.position.x, p.y - btnJump.position.y) < 92 { return 2 }
        let mid = (btnLeft.position.x + btnRight.position.x) / 2
        if p.y < btnLeft.position.y + 100 && abs(p.x - mid) < 150 { return p.x < mid ? 0 : 1 }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let id = buttonID(at: t.location(in: cam)) else { continue }
            if id == 3 { togglePause(); continue }
            if gamePaused || dead { continue }
            touchMap[t] = id
            if id == 2 {
                jumpBuffer = 0.14
                jumpHeld = true
            }
        }
        refreshButtons()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let cur = touchMap[t], cur != 2 else { continue }
            if let id = buttonID(at: t.location(in: cam)), id == 0 || id == 1 { touchMap[t] = id }
        }
        refreshButtons()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release(touches) }

    private func release(_ touches: Set<UITouch>) {
        var releasedJump = false
        for t in touches {
            if touchMap[t] == 2 { releasedJump = true }
            touchMap[t] = nil
        }
        jumpHeld = touchMap.values.contains(2)
        if releasedJump && !jumpHeld {
            // Kurz tippen = kleiner Sprung, gedrückt halten = voller Sprung
            if canCut && vel.dy > 300 && rocketTime <= 0 { vel.dy *= 0.55 }
            canCut = false
        }
        refreshButtons()
    }

    private func refreshButtons() {
        leftHeld = touchMap.values.contains(0)
        rightHeld = touchMap.values.contains(1)
        let jumpDown = touchMap.values.contains(2)
        btnLeft.setScale(leftHeld ? 0.88 : 1)
        btnLeft.alpha = leftHeld ? 1 : 0.75
        btnRight.setScale(rightHeld ? 0.88 : 1)
        btnRight.alpha = rightHeld ? 1 : 0.75
        btnJump.setScale(jumpDown ? 0.88 : 1)
        btnJump.alpha = jumpDown ? 1 : 0.75
    }
}
