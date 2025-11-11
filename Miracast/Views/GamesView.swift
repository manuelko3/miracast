import SwiftUI

struct GamesView: View {
    @Binding var isPresented: Bool
    @State private var installedGames: [GameApp] = []

    var body: some View {
        ZStack {
            // Градиентный фон как во всем приложении
            LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Верхняя панель навигации
                ZStack {
                    // Центрированный заголовок
                    Text("My Games")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Левая кнопка - назад
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(width: 44, height: 44)
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Список игр в виде сетки
                if installedGames.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No games found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                        Text("Install gaming apps to see them here")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 24) {
                            ForEach(installedGames) { game in
                                GameCardView(game: game)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .onAppear {
            loadInstalledGames()
        }
    }

    private func loadInstalledGames() {
        // Список популярных игр с их URL schemes
        let knownGames = [
            GameApp(name: "Among Us", bundleId: "amongus://"),
            GameApp(name: "PUBG Mobile", bundleId: "pubgmobile://"),
            GameApp(name: "Call of Duty", bundleId: "codm://"),
            GameApp(name: "Fortnite", bundleId: "fortnite://"),
            GameApp(name: "Roblox", bundleId: "robloxmobile://"),
            GameApp(name: "Minecraft", bundleId: "minecraft://"),
            GameApp(name: "Brawl Stars", bundleId: "brawlstars://"),
            GameApp(name: "Clash of Clans", bundleId: "clashofclans://"),
            GameApp(name: "Clash Royale", bundleId: "clashroyale://"),
            GameApp(name: "Candy Crush", bundleId: "candycrush://"),
            GameApp(name: "Subway Surfers", bundleId: "subwaysurfers://"),
            GameApp(name: "Asphalt 9", bundleId: "asphalt9://"),
            GameApp(name: "Mobile Legends", bundleId: "mobilelegends://"),
            GameApp(name: "Genshin Impact", bundleId: "genshinimpact://"),
            GameApp(name: "League of Legends", bundleId: "lolwr://"),
            GameApp(name: "Free Fire", bundleId: "freefire://"),
            GameApp(name: "8 Ball Pool", bundleId: "eightballpool://"),
            GameApp(name: "Temple Run", bundleId: "templerun://"),
            GameApp(name: "Angry Birds", bundleId: "angrybirds://"),
            GameApp(name: "Pokemon GO", bundleId: "pokemongo://"),
            GameApp(name: "Stumble Guys", bundleId: "stumbleguys://"),
            GameApp(name: "Hill Climb Racing", bundleId: "hillclimbracing://"),
            GameApp(name: "Fruit Ninja", bundleId: "fruitninja://"),
            GameApp(name: "Plants vs Zombies", bundleId: "pvz://"),
            GameApp(name: "Geometry Dash", bundleId: "geometrydash://"),
            GameApp(name: "Dragon City", bundleId: "dragoncity://"),
            GameApp(name: "Township", bundleId: "township://"),
            GameApp(name: "Homescapes", bundleId: "homescapes://"),
            GameApp(name: "Gardenscapes", bundleId: "gardenscapes://"),
            GameApp(name: "Shadow Fight", bundleId: "shadowfight://"),
        ]

        // Проверяем, какие игры установлены
        var foundGames: [GameApp] = []

        for game in knownGames {
            if let url = URL(string: game.bundleId) {
                if UIApplication.shared.canOpenURL(url) {
                    foundGames.append(game)
                }
            }
        }

        installedGames = foundGames
    }
}

struct GameCardView: View {
    let game: GameApp

    var body: some View {
        VStack(spacing: 8) {
            // Иконка игры
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 80)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.4))
                )

            // Название игры
            Text(game.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct GameApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
}
