//
//  Indexed.swift
//  GitVault
//
//  交错入场动画需要「元素 + 序号」。这里用显式包装类型替代 `id: \.offset`
//  这类元组 KeyPath 写法，保证在所有 Swift 版本下都能编译，同时保持可读性。
//

import Foundation

struct Indexed<Item: Identifiable>: Identifiable {
    let index: Int
    let item: Item
    var id: Item.ID { item.id }
}

extension Array where Element: Identifiable {
    /// 带序号的数组副本，供 ForEach + staggerAppear(index) 使用
    var indexed: [Indexed<Element>] {
        enumerated().map { Indexed(index: $0.offset, item: $0.element) }
    }
}
