# 外幣保險資格測驗 App — 設計規格

日期:2026-09-02
狀態:待使用者覆核

## 1. 專案目標

參考壽險考照 app(`/Users/fortune/insurance-exam-app`)前後台架構,製作「外幣保險資格測驗認證班」考照練習網頁,主打「不只是題庫,而是內建口訣外掛的記憶型 app」,並針對上年紀考生的學習/介面需求優化,提高及格率。

純網頁形式,不做原生 App 上架,需在各廠牌手機瀏覽器上跑得順。

## 2. 來源素材(本機)

位於 `/Users/fortune/Documents/外幣/`:

| 檔案 | 內容 |
|---|---|
| 外幣課程表.pdf | 官方考試章節結構(5章:緒論/業務概論/非投資型業務規範/銷售注意事項/相關法規) |
| 外幣題庫_ABECD卷整理V1.pdf | 32頁,A/B/C/D/E 共5份試卷,約250–300題,每題含題號/答案/選項/答案說明(含課本頁碼引用) |
| 外幣證照必勝寶典_授課簡報V1.pdf | 263頁投影片(即答案說明所指「課本」),含「外幣考照八大重點方向」分類法 |

**關鍵發現**:題庫的「答案說明」欄位裡,已內嵌題庫作者自己寫的壓縮口訣(例如「風險值口訣『週三、日一、週九九、十月』」「金三角」「十權」「總是」「費匯匯」「金證投」「構政制」等),經比對至少 8 題有明確標記,推測全題庫還有更多。這代表口訣卡內容主要是**萃取既有教材**,不是憑空生成,大幅降低內容失真風險。

## 3. 章節結構(依使用者決定)

採用投影片「外幣考照八大重點方向」而非官方 5 章:
1. 外幣保險開放紀事
2. 保險業辦理外匯業務管理辦法
3. 人身保險業辦理以外幣收付之非投資型人身保險業務應具備資格條件及注意事項
4. 管理外匯條例
5. 外匯收支或交易申報辦法
6. 投資型保險投資管理辦法
7. 保險業辦理國外投資管理辦法
8. 人身保險基本概念及其他

## 4. 整體架構決策

**以 `insurance-exam-app` 的 Flutter Web 版為模板複製改造**,而非重寫或沿用 `property-insurance-exam` 的純 HTML 單檔架構。理由:繼承已驗證能在真實學員手機瀏覽器上運作的 LK 授權碼登入、本機優先+雲端同步的錯題本/收藏機制、測驗引擎、教材翻頁閱讀器、考試計時器,只需專心做這次真正新增的部分。

沿用/繼承的既有模組:
- `lib/core/services/lk_auth_service.dart`(授權碼+裝置綁定登入)
- `lib/core/services/cloud_sync_service.dart` + `SharedPreferencesStore`(本機優先、fire-and-forget 同步到 Supabase 的模式)
- `lib/core/services/study_logger.dart`(學習行為事件記錄)
- 測驗引擎(quiz/exam)、教材圖片翻頁閱讀器、考試計時器

**新的 Supabase 專案**(不共用壽險那個),沿用相同的 `license_keys` + `study_logs` 表結構設計。

## 5. 使用者存取模式

沿用授權碼(License Key)綁裝置模式,比照壽險版由訓練中心/公司發放授權碼,學員輸入登入。非公開自由註冊。

## 6. 內容更新機制

**改為 Supabase 可編輯內容**,取代壽險版「內容寫死 JSON、改內容要重新 deploy」的做法。`course` / `chapters` / `questions` / `sections` / `mnemonic_cards` 全部改成 Supabase 資料表,app 啟動時抓取、本機快取。

v1 內容編輯直接使用 **Supabase 內建 Table Editor**,不另外開發自訂 CMS 介面(YAGNI——之後若手動編輯體驗太差,再評估要不要做專屬後台編輯畫面)。

## 7. 資料模型

```
course: { id, name, description }

chapters: { id, courseId, unitNo, title, weight }  // 8 大主題；unitNo/weight 沿用既有 Chapter model 欄位名稱(weight 外幣版固定為空字串,無章節配分資料)

questions: {
  id, chapterId, questionNo, question, options[], answer,
  explanation,        // 原本法規式解析(沿用壽險欄位)
  keywordHint,        // 新增:「關鍵字破題」一句話秒殺提示
  plainExplanation,   // 新增:白話為什麼
  textbookPage        // 對應課本(263頁投影片)頁碼,銜接教材翻頁器
}

mnemonic_cards: {
  id, chapterId, phrase, meaning[], source: "original" | "ai_generated",
  relatedQuestionIds[]
}

sections: { id, chapterId, order, title, content }  // 章節重點筆記(沿用壽險格式)

levels: { id, order, label, chapterId, questionIds[], passThreshold: 0.7 }  // 18 關地圖

level_progress: { levelId, attempted, correct, passed, lastAttemptAt }

wrong_book: {
  questionId, wrongCount, lastWrongTime,
  correctStreak,     // 新增
  nextReviewDate     // 新增
}

license_keys, study_logs  // 沿用壽險表結構
```

## 8. 新功能設計

### 8.1 口訣卡(Mnemonic Cards)
- 內容來源分兩類並在 `source` 欄位標註:`original`(題庫/課本原文逐字萃取,可信度高)、`ai_generated`(既有規則但題庫未提供壓縮口訣,由 AI 依相同風格新創,**需人工覆核**後才能標記為可信內容上線)
- 呈現:卡片式,可一鍵收藏,考前快速刷卡複習

### 8.2 關鍵字破題 + 白話雙向解析
- 每題新增 `keywordHint`(秒殺提示)與 `plainExplanation`(白話說明),與原本法規式 `explanation` 並存,UI 上以「🎯 關鍵字破題」「💬 白話告訴你為什麼」兩個可展開區塊呈現

### 8.3 18 關卡地圖(比照壽險課程「18小節綠燈」)
- 依題量將 8 大主題平均拆分/合併成 18 關,每關約 12–15 題
- **不強制鎖關**:所有關卡隨時可點開練習,答對率達 70% 才會讓地圖上的燈亮綠,降低操作挫折感,對長者更友善(可依需求改回硬性闖關)

### 8.4 錯題本雙重驗證 + 複習排程
- 答錯 → `correctStreak=0`,`nextReviewDate=+1天`
- 到期後在「複習模式」答對 → `correctStreak+=1`;第1次答對 →`nextReviewDate=+3天`;第2次連續答對(streak≥2)→ 自動移出錯題本
- 期間答錯一次 → streak 歸零,重新從 +1天排起
- **只有在「複習模式」作答才計入 streak**,避免平常練習巧合刷到同一題答對被誤判為已學會
- 純網頁無推播,改為**首頁提醒卡**:「📌 今日待複習 N 題」,依 `nextReviewDate <= 今天` 計算,點擊直接進複習模式

## 9. 高齡友善設計原則(研究佐證)

- 內文字級 ≥16px,對比度文字 4.5:1、重要元素 7:1(WCAG)
- 行距 1.5–1.8 倍,段落間距比行距再大 1.3 倍,元素間留白避免緊迫感
- 操作步驟放慢,盡量用二選一(是/否)取代自由輸入;動態提示延長停留時間
- 語氣清楚但不說教,短句、每步驟給明確回饋
- 間隔複習(spaced repetition)對長者記憶保留同樣有效,支持第 8.4 節設計

參考來源:
- 科技大觀園〈高齡使用者介面設計 4 大原則〉
- Toptal〈A Guide to Interface Design for Older Adults〉
- NN/g〈UX Design for Seniors (Ages 65 and older)〉
- NCBI PMC9892402〈Preservation of long-term memory in older adults using a spaced learning paradigm〉

## 10. 內容產製計畫

1. **腳本化萃取**:掃描題庫全文(已轉出至純文字),抓「口訣」「→」等標記字元,批次產出 `mnemonic_cards`(`source: original`)草稿
2. **關鍵字破題**:從既有「【解析】」欄位改寫格式,批次產出 `keywordHint`
3. **白話雙向解析**:真正的新增撰寫工作,對全部 250–300 題逐題生成 `plainExplanation`,需人工抽查、特別留意法規正確性(高風險項目,不可照單全收)
4. **章節分類回推**:每題依答案說明的課本頁碼,對照課本(263頁投影片轉圖後)的頁碼→章節對照表,回推 `chapterId`(無法全自動,需人工抽查修正)
5. 教材投影片轉圖:`pdftoppm` 逐頁轉 PNG,人工/關鍵字比對標出 8 大主題的頁碼區間,產出對應的 guide_pages 結構

以上皆排在本 spec 覆核通過、進入 writing-plans 產出實作計畫之後,分批執行,逐一完成。

## 11. 待確認/開放風險

- 18關地圖採「軟解鎖」而非強制闖關,如使用者期望比照原課程硬性闖關,需調整
- `ai_generated` 口訣卡上線前必須人工覆核法規正確性,不可自動發布
- 章節分類回推(頁碼→章節)無法全自動,需人工抽查
- 白話雙向解析屬於高風險新增內容(法規正確性),需訂出人工覆核流程,不能單靠 AI 產出即上線
