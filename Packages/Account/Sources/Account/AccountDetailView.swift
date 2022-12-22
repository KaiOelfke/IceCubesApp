import SwiftUI
import Models
import Network
import Status
import Shimmer
import DesignSystem
import Routeur

public struct AccountDetailView: View {  
  @Environment(\.redactionReasons) private var reasons
  @EnvironmentObject private var client: Client
  @EnvironmentObject private var routeurPath: RouterPath
  
  @StateObject private var viewModel: AccountDetailViewModel
  @State private var scrollOffset: CGFloat = 0
  @State private var isFieldsSheetDisplayed: Bool = false
  
  private let isCurrentUser: Bool
  
  /// When coming from a URL like a mention tap in a status.
  public init(accountId: String) {
    _viewModel = StateObject(wrappedValue: .init(accountId: accountId))
    isCurrentUser = false
  }
  
  /// When the account is already fetched by the parent caller.
  public init(account: Account, isCurrentUser: Bool = false) {
    _viewModel = StateObject(wrappedValue: .init(account: account,
                                                 isCurrentUser: isCurrentUser))
    self.isCurrentUser = isCurrentUser
  }
  
  public var body: some View {
    ScrollViewOffsetReader { offset in
      self.scrollOffset = offset
    } content: {
      LazyVStack {
        headerView
        featuredTagsView
          .offset(y: -36)
        if isCurrentUser {
          Picker("", selection: $viewModel.selectedTab) {
            ForEach(AccountDetailViewModel.Tab.allCases, id: \.self) { tab in
              Text(tab.title).tag(tab)
            }
          }
          .pickerStyle(.segmented)
          .padding(.horizontal, DS.Constants.layoutPadding)
          .offset(y: -20)
        } else {
          Divider()
            .offset(y: -20)
        }
        
        switch viewModel.tabState {
        case .statuses:
          StatusesListView(fetcher: viewModel)
        case let .followedTags(tags):
          makeTagsListView(tags: tags)
        }
      }
    }
    .task {
      guard reasons != .placeholder else { return }
      viewModel.client = client
      await viewModel.fetchAccount()
      if viewModel.statuses.isEmpty {
        await viewModel.fetchStatuses()
      }
    }
    .refreshable {
      Task {
        await viewModel.fetchAccount()
        await viewModel.fetchStatuses()
      }
    }
    .edgesIgnoringSafeArea(.top)
    .navigationTitle(Text(scrollOffset < -20 ? viewModel.title : ""))
  }
  
  @ViewBuilder
  private var headerView: some View {
    switch viewModel.accountState {
    case .loading:
      AccountDetailHeaderView(isCurrentUser: isCurrentUser,
                              account: .placeholder(),
                              relationship: .constant(.placeholder()),
                              following: .constant(false),
                              scrollOffset: $scrollOffset)
        .redacted(reason: .placeholder)
    case let .data(account):
      AccountDetailHeaderView(isCurrentUser: isCurrentUser,
                              account: account,
                              relationship: $viewModel.relationship,
                              following:
      .init(get: {
        viewModel.relationship?.following ?? false
      }, set: { following in
        Task {
          if following {
            await viewModel.follow()
          } else {
            await viewModel.unfollow()
          }
        }
      }),
                              scrollOffset: $scrollOffset)
    case let .error(error):
      Text("Error: \(error.localizedDescription)")
    }
  }
    
  @ViewBuilder
  private var featuredTagsView: some View {
    if !viewModel.featuredTags.isEmpty || !viewModel.fields.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
          if !viewModel.fields.isEmpty {
            Button {
              isFieldsSheetDisplayed.toggle()
            } label: {
              VStack(alignment: .leading, spacing: 0) {
                Text("About")
                  .font(.callout)
                Text("\(viewModel.fields.count) fields")
                  .font(.caption2)
              }
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $isFieldsSheetDisplayed) {
              fieldSheetView
            }
          }
          if !viewModel.featuredTags.isEmpty {
            ForEach(viewModel.featuredTags) { tag in
              Button {
                routeurPath.navigate(to: .hashTag(tag: tag.name, account: viewModel.accountId))
              } label: {
                VStack(alignment: .leading, spacing: 0) {
                  Text("#\(tag.name)")
                    .font(.callout)
                  Text("\(tag.statusesCount) posts")
                    .font(.caption2)
                }
              }.buttonStyle(.bordered)
            }
          }
        }
        .padding(.leading, DS.Constants.layoutPadding)
      }
    }
  }
  
  private var fieldSheetView: some View {
    NavigationStack {
      List {
        ForEach(viewModel.fields) { field in
          VStack(alignment: .leading, spacing: 2) {
            Text(field.name)
              .font(.headline)
            HStack {
              if field.verifiedAt != nil {
                Image(systemName: "checkmark.seal")
                  .foregroundColor(Color.green.opacity(0.80))
              }
              Text(field.value.asSafeAttributedString)
                .foregroundColor(.brand)
            }
            .font(.body)
          }
          .listRowBackground(field.verifiedAt != nil ? Color.green.opacity(0.15) : nil)
        }
      }
      .navigationTitle("About")
    }
  }
  
  private func makeTagsListView(tags: [Tag]) -> some View {
    Group {
      ForEach(tags) { tag in
        HStack {
          VStack(alignment: .leading) {
            Text("#\(tag.name)")
              .font(.headline)
            Text("\(tag.totalUses) posts from \(tag.totalAccounts) participants")
              .font(.footnote)
              .foregroundColor(.gray)
          }
          Spacer()
        }
        .padding(.horizontal, DS.Constants.layoutPadding)
        .padding(.vertical, 8)
        .onTapGesture {
          routeurPath.navigate(to: .hashTag(tag: tag.name, account: nil))
        }
      }
    }
  }
}

struct AccountDetailView_Previews: PreviewProvider {
  static var previews: some View {
    AccountDetailView(account: .placeholder())
  }
}
