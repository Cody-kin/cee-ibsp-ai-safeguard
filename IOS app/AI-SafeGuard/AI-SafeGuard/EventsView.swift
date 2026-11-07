import SwiftUI

struct EventsView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @StateObject private var notifManager = NotificationManager.shared
    
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    let filters = ["All", "Critical", "High", "Info"]
    let imageBaseURL = "http://127.0.0.1/storage"
    @State private var navigatedEvent: SGEventObject?
    
    var filteredEvents: [SGEventObject] {
        var result = viewModel.events
        if selectedFilter != "All" { result = result.filter { $0.severity.lowercased() == selectedFilter.lowercased() } }
        if !searchText.isEmpty {
            result = result.filter { event in
                event.event_name.localizedCaseInsensitiveContains(searchText) ||
                (event.device_id ?? "").localizedCaseInsensitiveContains(searchText) ||
                event.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                Circle().fill(Color.themeIndigo.opacity(0.15)).blur(radius: 80).frame(width: 300, height: 300).offset(x: 150, y: -200)
                
                VStack(spacing: 0) {
                    CustomSearchBar(text: $searchText).padding(.bottom, 8).padding(.top, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) { ForEach(filters, id: \.self) { filter in FilterChip(title: filter, isSelected: selectedFilter == filter) { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedFilter = filter } } } }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }.background(Color.themeBg.opacity(0.8).background(.ultraThinMaterial))
                    
                    if viewModel.isAnalyzing && viewModel.events.isEmpty {
                        Spacer(); ProgressView("連線至指揮中心...").tint(.themeIndigo).foregroundColor(.gray); Spacer()
                    } else if filteredEvents.isEmpty {
                        Spacer()
                        VStack(spacing: 16) { Image(systemName: "magnifyingglass").font(.system(size: 48, weight: .light)).foregroundColor(.themeBorder); Text("NO PROTOCOLS FOUND").font(.headline).fontWeight(.black).foregroundColor(.gray); Text("沒有找到符合條件的監控日誌。").font(.subheadline).foregroundColor(.gray.opacity(0.7)) }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredEvents) { event in
                                    NavigationLink(value: event) { EventCard(event: event) }.buttonStyle(PlainButtonStyle())
                                }
                            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
                        }.refreshable { await viewModel.manualRefresh() }
                    }
                }
            }
            .navigationTitle("Global Audit").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SGEventObject.self) { event in EventDetailView(event: event, imageBaseURL: imageBaseURL) }
            .onChange(of: notifManager.tappedEventId) { eventId in if let id = eventId, let foundEvent = viewModel.events.first(where: { $0.id == id }) { navigatedEvent = foundEvent } }
            .navigationDestination(isPresented: Binding(get: { navigatedEvent != nil }, set: { if !$0 { navigatedEvent = nil } })) { if let event = navigatedEvent { EventDetailView(event: event, imageBaseURL: imageBaseURL) } }
        }
    }
}

struct CustomSearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜尋設備 (如 DEV-NANO) 或事件...", text: $text).foregroundColor(.white).tint(.themeIndigo).autocapitalization(.none)
            if !text.isEmpty { Button(action: { withAnimation { text = "" } }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) } }
        }.padding(.vertical, 12).padding(.horizontal, 16).background(Color.themeCard.opacity(0.4)).background(.ultraThinMaterial).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(LinearGradient(colors: [Color.themeIndigo.opacity(0.5), Color.themeBorder, Color.themeEmerald.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)).shadow(color: Color.black.opacity(0.2), radius: 8, y: 4).padding(.horizontal, 16)
    }
}

struct FilterChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var chipColor: Color {
        if !isSelected { return .themeBorder }
        switch title.lowercased() {
        case "critical": return .themeRose; case "high": return .orange; case "warning": return .orange; case "info": return .themeEmerald; default: return .themeIndigo
        }
    }
    var body: some View {
        Button(action: action) { Text(title.uppercased()).font(.caption).fontWeight(.bold).padding(.horizontal, 16).padding(.vertical, 8).foregroundColor(isSelected ? .white : .gray).background(Capsule().fill(isSelected ? chipColor.opacity(0.8) : Color.themeCard)).overlay(Capsule().stroke(chipColor, lineWidth: isSelected ? 1 : 0.5)).shadow(color: isSelected ? chipColor.opacity(0.4) : .clear, radius: 4) }
    }
}

struct EventCard: View {
    let event: SGEventObject
    var severityColor: Color {
        switch event.severity.lowercased() {
        case "critical": return .themeRose; case "high": return .orange; case "warning": return .orange; default: return .themeEmerald
        }
    }
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 4).fill(severityColor).frame(width: 4).shadow(color: severityColor.opacity(0.5), radius: 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(event.device_id ?? "SYSTEM").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                    Spacer()
                    // 🌟 使用本地時區顯示
                    Text(event.localTimeString).font(.caption2).foregroundColor(.gray)
                }
                Text(event.event_name).font(.headline).fontWeight(.black).foregroundColor(.white)
                Text(event.description).font(.subheadline).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            if event.event_type == "ai_vision" { Image(systemName: "photo.badge.plus").foregroundColor(.themeIndigo).font(.system(size: 20)) } else { Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)).font(.system(size: 14)) }
        }.padding(16).glassCardStyle()
    }
}

struct EventDetailView: View {
    let event: SGEventObject
    let imageBaseURL: String
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    if event.event_type == "ai_vision" {
                        let imageUrl = URL(string: "\(imageBaseURL)/evt_\(event.id)_ai_vision.jpg")
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .empty: Rectangle().fill(Color.themeCard).frame(height: 220).overlay(ProgressView().tint(.themeIndigo))
                            case .success(let image): image.resizable().aspectRatio(contentMode: .fit).cornerRadius(16)
                            case .failure: Rectangle().fill(Color.themeCard).frame(height: 220).overlay(Text("影像加載失敗").foregroundColor(.gray))
                            @unknown default: EmptyView()
                            }
                        }.shadow(color: Color.black.opacity(0.5), radius: 10, y: 5).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "cpu").foregroundColor(.gray)
                            Text(event.device_id ?? "SYSTEM").font(.headline).foregroundColor(.white)
                            Spacer()
                            Text(event.severity.uppercased()).font(.caption).fontWeight(.bold).padding(.horizontal, 8).padding(.vertical, 4).background(event.severity.lowercased() == "critical" ? Color.themeRose.opacity(0.2) : Color.themeIndigo.opacity(0.2)).foregroundColor(event.severity.lowercased() == "critical" ? .themeRose : .themeIndigo).cornerRadius(8)
                        }
                        Divider().background(Color.themeBorder)
                        VStack(alignment: .leading, spacing: 8) { Text("EVENT TRIGGERED").font(.caption2).foregroundColor(.gray); Text(event.event_name).font(.title3).fontWeight(.bold).foregroundColor(.white) }
                        VStack(alignment: .leading, spacing: 8) { Text("TELEMETRY LOG").font(.caption2).foregroundColor(.gray); Text(event.description).font(.body).foregroundColor(.white) }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TIMESTAMP (LOCAL)").font(.caption2).foregroundColor(.gray)
                            // 🌟 使用本地時區顯示
                            Text(event.localTimeString).font(.body).foregroundColor(.white)
                        }
                    }.padding(20).glassCardStyle()
                }.padding(16)
            }
        }.navigationTitle("Event Analysis").navigationBarTitleDisplayMode(.inline)
    }
}
