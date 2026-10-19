import SwiftUI

struct WelcomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            // Window width, rather than device identity, also handles iPad multitasking.
            let usesColumns = geometry.size.width >= 760 && !dynamicTypeSize.isAccessibilitySize
            ScrollView {
                if usesColumns {
                    HStack(spacing: 48) {
                        WelcomeHero()
                            .frame(maxWidth: 440)
                            .clipShape(RoundedRectangle(cornerRadius: 40))
                        WelcomeIntroduction()
                            .frame(maxWidth: 400)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                } else {
                    VStack(spacing: 0) {
                        WelcomeHero()
                            .background(alignment: .top) {
                                WelcomeHeroGradient()
                                    .ignoresSafeArea(edges: .top)
                            }
                            .clipShape(UnevenRoundedRectangle(
                                bottomLeadingRadius: 40,
                                bottomTrailingRadius: 40
                            ))
                        WelcomeIntroduction()
                            .padding(.horizontal, 33)
                            .padding(.top, 50)
                            .padding(.bottom, 12)
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background {
                LinearGradient(
                    colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                if !usesColumns {
                    Color(red: 0.078, green: 0.235, blue: 0.455)
                        .frame(height: geometry.safeAreaInsets.top)
                        .offset(y: -geometry.safeAreaInsets.top)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct WelcomeHeroGradient: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.078, green: 0.235, blue: 0.455), location: 0),
                .init(color: Color(red: 0.078, green: 0.337, blue: 0.604), location: 0.6),
                .init(color: Color(red: 0.075, green: 0.482, blue: 0.576), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct WelcomeHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FuelSmart LK")
                .font(.largeTitle.bold())
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
            Text("Find Fuel.\nTravel Smarter.")
                .font(.title2.weight(.semibold))
                .padding(.top, 12)

            WelcomeFuelCard()
                .padding(.horizontal, 16)
                .padding(.top, 56)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 36)
        .padding(.top, 30)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WelcomeHeroGradient())
    }
}

private struct WelcomeFuelCard: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 20) {
                Image("WelcomeFuelPump")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 41.5, height: 36.5)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plan your fuel stop")
                        .font(.title3.weight(.semibold))
                    Text("Stations across Sri Lanka")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(contrast == .increased ? .white : Color(red: 0.643, green: 0.953, blue: 0.851))
                }
            }
            Text("Find stations and compare reported fuel information before you travel.")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            reduceTransparency ? Color(red: 0.23, green: 0.47, blue: 0.64) : Color.white.opacity(0.17),
            in: RoundedRectangle(cornerRadius: 28)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WelcomeIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Fuel decisions with confidence")
                .font(.system(.title2, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Color("WelcomeHeading"))
                .accessibilityAddTraits(.isHeader)
            Text("Find nearby stations and compare reported stock, prices and update times.")
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
                .padding(.top, 14)
                .fixedSize(horizontal: false, vertical: true)

            WelcomeActions()
                .padding(.top, 64)

            Text("FUELSMART LK  •  SRI LANKA")
                .font(.caption2)
                .foregroundStyle(Color("WelcomeSecondary"))
                .frame(maxWidth: .infinity)
                .padding(.top, 72)
        }
    }
}

private struct WelcomeActions: View {
    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(value: WelcomeRoute.signIn) {
                HStack(spacing: 4) {
                    Text("Get started")
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.161, green: 0.486, blue: 0.902),
                            Color(red: 0.078, green: 0.314, blue: 0.780)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("welcome.getStarted")

            NavigationLink(value: WelcomeRoute.returningCustomer) {
                Text("Returning customer  ·  Face ID")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color("WelcomeAccent"))
            .accessibilityIdentifier("welcome.returningCustomer")
        }
    }
}
