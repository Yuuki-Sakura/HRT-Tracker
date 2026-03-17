# HRT-Tracker

HRT-Tracker — 一款基于药代动力学（PK）模型的激素替代疗法追踪应用。

A pharmacokinetic model-based Hormone Replacement Therapy (HRT) tracking application.

**Platform**: iOS 18+ / iPadOS 18+ / watchOS 11+ / macOS 15+
**Language**: Swift 6, SwiftUI, SwiftData

---

## Algorithm & Core Logic 算法与核心逻辑

本项目的药代动力学算法、数学模型与参数来源于 **[HRT-Recorder-PKcomponent-Test](https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test)** 仓库（@LaoZhong-Mihari）。

The pharmacokinetic algorithms, mathematical models, and parameters used in this project are derived from the **[HRT-Recorder-PKcomponent-Test](https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test)** repository by @LaoZhong-Mihari.

在此基础上，本项目做了以下改进：

Based on the original engine, this project introduces the following improvements:

- **CPA（醋酸环丙孕酮）支持** — 新增 CPA 口服 PK 建模，参数直接取自文献
- **贴片皮肤储库模型** — 新增角质层药物储库室，更准确地模拟贴片移除后的缓慢衰减
- **实验室校准** — 支持用真实血检结果校正模拟曲线，使用逆距离加权（IDW）+ 时间衰减的校准比值插值，详见 Algorithm Explanation.md §10

详细的数学模型推导请参见 [Algorithm Explanation.md](HRT-Tracker/Algorithm%20Explanation.md)。

### 参数差异对比 Parameter Differences

以下为本项目与 [HRT-Recorder-PKcomponent-Test](https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test)（原始引擎）和 [Oyama's HRT-Tracker](https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker)（Web 移植版）之间的参数差异。

**E2 核心参数（三项目完全一致）**：vdPerKG = 2.0 L/kg，kClear = 0.41 h⁻¹，kClearInjection = 0.041 h⁻¹，所有注射双库参数（Frac_fast, k1_fast, k1_slow）、酯水解速率（k2）、口服参数（kAbsE2 = 0.32, kAbsEV = 0.05, F = 0.03）、舌下参数（kAbsSL = 1.8, theta 四档）均一致。

#### CPA（醋酸环丙孕酮）参数

| 参数 | HRT-Recorder | Oyama's | HRT-Tracker（本项目） | 文献值 | 来源 |
|---|---|---|---|---|---|
| 是否支持 | 否 | 是 | 是 | — | — |
| Vd (L/kg) | — | 14.0 | **20.6** | 20.6 +/- 3.5 | <sup><a href="#ref1">[1]</a></sup> |
| ka (h⁻¹) | — | 1.0 | **0.35** | Tmax 2-3 h | <sup><a href="#ref1">[1]</a></sup> |
| kel (h⁻¹) | — | 0.017 | 0.017 | t1/2 38-53 h | <sup><a href="#ref2">[2]</a></sup> |
| F (生物利用度) | — | 0.7 | **0.88** | 68-100% | <sup><a href="#ref3">[3]</a></sup> |

**差异原因**：

- **Vd**：本项目采用 20.6 L/kg，直接取自 Frith & Piper (1987) 的药代动力学研究<sup><a href="#ref1">[1]</a></sup>，报告值 20.6 +/- 3.5 L/kg。Oyama 的 14.0 L/kg 可能取自 DrugBank 的不同数据源。
- **ka**：0.35 h⁻¹ 对应 Tmax 约 2-3 h，与 CPA 口服临床文献一致<sup><a href="#ref1">[1]</a></sup>。Oyama 的 1.0 h⁻¹ 会导致 Tmax < 1 h，显著快于文献报告值。
- **F**：0.88 是文献报告范围 68-100% 的中位值<sup><a href="#ref3">[3]</a></sup>（Humpel et al. 1977）。0.7 处于范围下限。

#### 贴片模型

| 方面 | HRT-Recorder / Oyama's | HRT-Tracker（本项目） |
|---|---|---|
| 模型结构 | 直接一室（Patch -> Plasma -> Elimination） | **皮肤储库双室**（Patch -> Skin Depot -> Plasma -> Elimination） |
| kSkin | 无 | **0.10 h⁻¹**（t1/2 约 6.93 h） |
| 移除后行为 | 以 kClear=0.41 快速消除（t1/2 约 1.69 h） | 皮肤储库持续排空，表观 t1/2 约 6.93 h |
| 阴囊贴片 | 不支持 | **F×5**（scrotalMultiplier = 5.0，基于 Premoli et al. 2005） |

**差异原因**：角质层充当药物储库，是经皮吸收的限速步骤。贴片移除后皮肤储库仍持续排空，产生文献中报告的表观 t1/2 = 5.9-7.7 h 的缓慢衰减，而非立即下降。kSkin = 0.10 h⁻¹ 由 Vivelle-Dot FDA Label<sup><a href="#ref4">[4]</a></sup> 报告的移除后半衰期拟合得到。阴囊贴敷时生物利用度约为常规部位 5 倍，基于 Premoli et al. (2005)<sup><a href="#ref11">[11]</a></sup> 的直接数据。

#### 凝胶涂抹部位

| 方面 | HRT-Recorder | Oyama's | HRT-Tracker |
|---|---|---|---|
| 生物利用度 F | 0.05（固定） | 部位相关（arm 0.05, thigh 0.05, scrotal 0.40） | 部位相关（常规 0.05, scrotal 0.25） |

**差异原因**：

- **HRT-Tracker F=0.25（阴囊）**：基于 Premoli et al. (2005)<sup><a href="#ref11">[11]</a></sup> 雌二醇贴片 35 人样本的直接数据，阴囊贴片 E2 水平约为常规部位 5 倍（~500 vs ~100 pg/mL），因此采用 5× 基础 F（0.05 × 5 = 0.25）。
- **Oyama F=0.40（阴囊）**：基于睾酮凝胶研究间接推算的上限估计（约 8× 基础 F），而非雌二醇的直接数据。
- 本项目选择更保守的 F=0.25，因为它基于雌二醇的直接临床数据而非睾酮的类推。

## Features 功能

**多给药途径模拟 Multi-Route Simulation**

- **注射 Injection**（EB / EV / EC / EN）— 双库三室模型
- **贴片 Patch**（E2）— 皮肤储库双室模型（零阶/一阶输入，支持阴囊贴敷 F×5）
- **凝胶 Gel**（E2）— 单室 Bateman 模型
- **口服 Oral**（E2 / EV）— 单室 Bateman 模型
- **舌下 Sublingual**（E2 / EV）— 双通路模型（黏膜快通路 + 胃肠慢通路）
- **CPA 口服**（醋酸环丙孕酮）— 独立单室 Bateman 模型

**浓度图表 Concentration Chart**

- E2 + CPA 双轴实时浓度曲线（E2 pg/mL / CPA ng/mL）
- 交互式 Tooltip 与小地图缩略导航
- 给药事件标记点
- 144h 默认时间窗口

**数据管理 Data Management**

- SwiftData 持久化存储
- 剂量模板保存与复用
- 实验室血检结果录入与校准叠加
- JSON / CSV / 加密数据导出导入

**系统集成 System Integration**

- HealthKit 集成（体重同步、药物记录导入）
- Apple Watch 配套应用（快速记录给药、迷你浓度图、与主应用同步）

**其他 Others**

- Localizable.xcstrings 多语言支持
- 应用内算法说明文档（KaTeX 渲染）

---

## Build & Run 构建与运行

### 环境要求 Requirements

- Xcode 16+
- Swift 6
- iOS 18+ / iPadOS 18+ / watchOS 11+ / macOS 15+
- Node.js 18+（仅用于 Git Hooks）

### 步骤 Steps

1. **克隆仓库 Clone the repository**

   ```bash
   git clone https://github.com/LaoZhong-Mihari/HRT-Tracker.git
   cd HRT-Tracker
   ```

2. **安装 Git Hooks Install git hooks**

   ```bash
   npm install
   ```

   这会安装 `lint-staged`（pre-commit 时对暂存的 `.swift` 文件运行 SwiftLint）和 `git-commit-msg-linter`（检查提交消息格式）。

   This installs `lint-staged` (runs SwiftLint on staged `.swift` files at pre-commit) and `git-commit-msg-linter` (validates commit message format).

3. **打开项目 Open the project**

   ```bash
   open HRT-Tracker.xcodeproj
   ```

4. **选择 Scheme 并运行 Select scheme and run**

   在 Xcode 中选择 `HRT-Tracker` (iOS) 或 `HRT-Tracker Watch App` (watchOS) scheme，然后点击 Run。

> **注意**：HealthKit 和 CloudKit（iCloud 同步）功能需要付费 Apple Developer 账号及对应的 entitlements 签名配置。免费开发者账号构建时使用 `OPENSOURCE` 编译标志和空 entitlements (`HRT_Tracker_OSS.entitlements`)，HealthKit 与 CloudKit 相关功能将不可用，其余功能不受影响。

---

## References 参考文献

<a id="ref1"></a>**[1]** Frith RG, Piper JM. Pharmacokinetics of cyproterone acetate. *Clin Pharmacol Ther*. 1987. [PMID 2977383](https://pubmed.ncbi.nlm.nih.gov/2977383/)

<a id="ref2"></a>**[2]** Barradell LB, Faulds D. Cyproterone: a review of its pharmacology. 1994. [PMID 9349934](https://pubmed.ncbi.nlm.nih.gov/9349934/)

<a id="ref3"></a>**[3]** Humpel M et al. Bioavailability and pharmacokinetics of CPA. *Contraception*. 1977. [PMID 880829](https://pubmed.ncbi.nlm.nih.gov/880829/)

<a id="ref4"></a>**[4]** [Vivelle-Dot (estradiol transdermal system) FDA label (2014, NDA 020538)](https://www.accessdata.fda.gov/drugsatfda_docs/label/2014/020538s032lbl.pdf)

<a id="ref5"></a>**[5]** Transfem Science. [Injectable estradiol meta-analysis](https://transfemscience.org/articles/injectable-e2-meta-analysis/)

<a id="ref6"></a>**[6]** Transfem Science. [Sublingual estradiol overview](https://transfemscience.org/articles/sublingual-e2-transfem/)

<a id="ref7"></a>**[7]** Wikipedia. [Pharmacokinetics of estradiol](https://en.wikipedia.org/wiki/Pharmacokinetics_of_estradiol)

<a id="ref8"></a>**[8]** Wikipedia. [Pharmacology of cyproterone acetate](https://en.wikipedia.org/wiki/Pharmacology_of_cyproterone_acetate)

<a id="ref9"></a>**[9]** DrugBank. [Estradiol (DB00783)](https://go.drugbank.com/drugs/DB00783)

<a id="ref10"></a>**[10]** DrugBank. [Cyproterone acetate (DB04839)](https://go.drugbank.com/drugs/DB04839)

<a id="ref11"></a>**[11]** Premoli F et al. Scrotal vs non-scrotal transdermal estradiol patch in hypogonadal men. *Maturitas*. 2005;52(2):111-118. [PMID 16186074](https://pubmed.ncbi.nlm.nih.gov/16186074/)

---

## Credits 致谢

- **@LaoZhong-Mihari** — 原始 HRT-Recorder PK 引擎 / Original PK engine ([HRT-Recorder-PKcomponent-Test](https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test))
- **@SmirnovaOyama** — Web TypeScript 移植版 / Web port ([Oyama's HRT-Tracker](https://github.com/SmirnovaOyama/Oyama-s-HRT-Tracker))
- [Transfem Science](https://transfemscience.org/) — 临床参考文献 / Clinical references
- [mtf.wiki](https://mtf.wiki/) — 社区文档资源 / Community documentation

---

## LICENCE

本项目遵守 MIT Licence。
