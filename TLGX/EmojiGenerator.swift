//
//  EmojiGenerator.swift
//  TLGX
//
//  Keyword-based emoji picker for Live Activity compact leading.
//

import Foundation
import SwiftUI

enum EmojiGenerator {

    /// Ordered mapping: first match wins.
    /// Each entry also carries a tint color used as the row/composer background.
    private static let mapping: [(keywords: [String], emoji: String, tint: Color)] = [
        (["吃药", "服药", "药", "医", "诊", "病", "体检", "打针", "疫苗"],             "💊", .pink),
        (["喝水", "补水"],                                                          "💧", .cyan),
        (["咖啡", "茶", "饮料", "果汁", "奶茶"],                                     "☕️", .brown),
        (["吃饭", "吃", "饭", "餐", "早餐", "午餐", "晚餐", "早饭", "午饭", "晚饭",
          "外卖", "点餐", "食"],                                                     "🍽️", .orange),
        (["跑步", "跑", "健身", "锻炼", "运动", "步行", "散步", "瑜伽", "游泳",
          "骑车", "打球", "徒步"],                                                   "🏃", .green),
        (["会议", "开会", "汇报", "演讲", "面试", "会", "讨论"],                      "📅", .indigo),
        (["电话", "打电话", "联系", "回电", "回复", "短信", "微信"],                   "📞", .green),
        (["睡觉", "睡", "休息", "午睡", "早睡"],                                     "😴", .purple),
        (["购物", "超市", "快递", "取件", "买", "购", "采购", "下单"],                 "🛒", .orange),
        (["作业", "学习", "复习", "考试", "读书", "看书", "背", "练习", "学"],          "📚", .blue),
        (["生日", "纪念日", "周年", "庆", "派对", "庆祝"],                            "🎂", .pink),
        (["付款", "缴费", "还款", "转账", "还钱", "收款", "账单", "钱", "费"],          "💰", .yellow),
        (["飞机", "火车", "高铁", "出发", "旅行", "旅游", "出行", "出差"],             "✈️", .blue),
        (["接孩子", "送孩子", "上学", "放学", "接送"],                                "🚗", .teal),
        (["工作", "任务", "截止", "deadline", "提交", "交"],                          "💼", .gray),
        (["见面", "约", "聚餐", "聚会", "朋友"],                                     "👥", .mint),
        (["充电"],                                                                  "🔋", .green),
        (["浇花", "浇水", "植物", "花"],                                             "🌱", .green),
        (["遛狗", "遛", "狗", "猫", "宠物"],                                        "🐾", .brown),
        (["垃圾", "倒垃圾", "扔垃圾"],                                               "🗑️", .gray),
        (["洗澡", "洗头", "洗衣", "晾衣", "收衣"],                                   "🚿", .cyan),
    ]

    /// Default fallback emoji when nothing matches.
    static let fallback = "🔔"
    /// Default tint for the fallback emoji.
    static let fallbackTint: Color = .indigo

    /// Returns the best-matching emoji for the given reminder title.
    /// Falls back to `fallback` if no keyword matches.
    static func emoji(for title: String) -> String {
        for entry in mapping {
            for keyword in entry.keywords where title.contains(keyword) {
                return entry.emoji
            }
        }
        return fallback
    }

    /// Returns the tint color for the given emoji (auto or user-picked).
    static func tint(for emoji: String) -> Color {
        for entry in mapping where entry.emoji == emoji {
            return entry.tint
        }
        return fallbackTint
    }

    /// Curated list of emojis exposed in the picker UI (one per category),
    /// in the same order as `mapping` so users see them grouped semantically.
    static var pickerEmojis: [String] {
        mapping.map { $0.emoji } + [fallback]
    }
}

