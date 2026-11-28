//
//  CodeBrowserView.swift
//  GitVault
//
//  代码结构浏览：git/trees 拿目录树，raw.githubusercontent 取文件内容（不消耗 API 额度）。
//

import SwiftUI

@MainActor
final class CodeBrowserViewModel: ObservableObject {
    @Published var entries: [GitHubExtrasService.TreeEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var branch = "main"

    private var didLoad = false

    func load(owner: String, repo: String) async {
        guard !didLoad else { return }
        didLoad = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        for candidate in ["main", "master"] {
            do {
                let list = try await GitHubExtrasService.shared.tree(owner: owner, repo: repo, branch: candidate)
                if !list.isEmpty {
                    entries = list
                    branch = candidate
                    return
                }
            } catch is CancellationError {
                return
            } catch {
                continue
            }
        }
        errorMessage = "没能读取代码结构（可能是空仓库或分支名不常见）"
    }
}

struct CodeBrowserView: View {
    let repo: ShowcaseRepo

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = CodeBrowserViewModel()

    private var groups: [(folder: String, items: [GitHubExtrasService.TreeEntry])] {
        var map: [String: [GitHubExtrasService.TreeEntry]] = [:]
        for entry in vm.entries {
            let folder = entry.path.contains("/")
                ? String(entry.path.split(separator: "/").dropLast().joined(separator: "/"))
                : "根目录"
            map[folder.isEmpty ? "根目录" : folder, default: []].append(entry)
        }
        return map
            .sorted { $0.key < $1.key }
            .map { (folder: $0.key, items: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("正在读取目录树…")
                        .tint(DS.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage {
                    VStack(spacing: DS.Space.s) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 28))
                            .foregroundStyle(DS.textTertiary)
                        Text(error)
                            .font(DS.Typo.bodySmall)
                            .foregroundStyle(DS.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DS.Space.l)
                } else {
                    List {
                        ForEach(groups, id: \.folder) { group in
                            Section {
                                ForEach(group.items) { entry in
                                    NavigationLink {
                                        CodeFileView(repo: repo,
                                                     branch: vm.branch,
                                                     path: entry.path)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: icon(for: entry))
                                                .font(.system(size: 12))
                                                .foregroundStyle(DS.accent.opacity(0.8))
                                                .frame(width: 16)
                                            Text(entry.fileName)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundStyle(DS.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            if let size = entry.size {
                                                Text(byteText(size))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(DS.textTertiary)
                                            }
                                        }
                                    }
                                }
                            } header: {
                                Text(group.folder)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DS.textTertiary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DS.bgPrimary)
            .navigationTitle("代码结构")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(vm.entries.count) 个文件 · \(vm.branch)")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .task { await vm.load(owner: repo.owner, repo: repo.name) }
        }
    }

    private func icon(for entry: GitHubExtrasService.TreeEntry) -> String {
        let ext = entry.path.split(separator: ".").last.map(String.init)?.lowercased() ?? ""
        switch ext {
        case "md": return "doc.text"
        case "json", "yml", "yaml", "toml": return "gearshape"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "swift", "kt", "java", "m", "mm": return "swift"
        case "js", "ts", "tsx", "jsx": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "sh": return "terminal"
        default: return "doc.plaintext"
        }
    }

    private func byteText(_ size: Int) -> String {
        if size > 1024 * 1024 { return String(format: "%.1fMB", Double(size) / 1024 / 1024) }
        if size > 1024 { return "\(size / 1024)KB" }
        return "\(size)B"
    }
}

// MARK: 单文件

@MainActor
final class CodeFileViewModel: ObservableObject {
    @Published var content: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(owner: String, repo: String, branch: String, path: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let text = try await GitHubExtrasService.shared.rawFile(owner: owner, repo: repo, branch: branch, path: path)
            content = text
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CodeFileView: View {
    let repo: ShowcaseRepo
    let branch: String
    let path: String

    @Environment(\.openURL) private var openURL
    @StateObject private var vm = CodeFileViewModel()
    @State private var searchText = ""

    /// 命中的行号（0 基）
    private var matchedLines: Set<Int> {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return [] }
        var result = Set<Int>()
        for (index, line) in lines.enumerated() where line.range(of: keyword, options: .caseInsensitive) != nil {
            result.insert(index)
        }
        return result
    }

    /// 超大文件只渲染前 2000 行：一次布局十万行文本会让主线程直接卡死
    private var lines: [String] {
        Array((vm.content ?? "").components(separatedBy: .newlines).prefix(2000))
    }

    private var truncated: Bool {
        (vm.content ?? "").components(separatedBy: .newlines).count > 2000
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                if vm.isLoading {
                    ProgressView().tint(DS.accent).padding(DS.Space.l)
                } else if let error = vm.errorMessage {
                    Text(error)
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.danger)
                        .padding(DS.Space.l)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(1...max(lines.count, 1), id: \.self) { number in
                                Text("\(number)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(DS.textTertiary)
                                    .frame(height: 16, alignment: .trailing)
                            }
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                Text(line.isEmpty ? " " : line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(DS.textPrimary)
                                    .frame(height: 16, alignment: .leading)
                                    .padding(.horizontal, 2)
                                    .background(
                                        matchedLines.contains(index)
                                            ? DS.warning.opacity(0.22)
                                            : Color.clear
                                    )
                            }
                        }
                    }
                    .padding(DS.Space.m)

                    if truncated {
                        Text("文件较长，仅显示前 2000 行。可用右上角复制全文。")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.textTertiary)
                            .padding(.horizontal, DS.Space.m)
                            .padding(.bottom, DS.Space.m)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.bgPrimary)
        .navigationTitle(path.split(separator: "/").last.map(String.init) ?? path)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "在文件中查找")
        .onChange(of: searchText) { _ in
            if !searchText.isEmpty { Haptics.selection() }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = vm.content
                    Haptics.success()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.accent)
                }
                .accessibilityLabel("复制全文")
            }
        }
        .task {
            await vm.load(owner: repo.owner, repo: repo.name, branch: branch, path: path)
        }
    }
}
