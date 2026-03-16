# HRT-Tracker 药代动力学模型说明

---

## 1 总览

**目标**：用一套轻量的、可解释的 PK 近似模型，覆盖常见雌激素制剂与给药途径，在移动端实时计算血药浓度–时间曲线与 AUC [^13][^14]。

### 1.1 核心构件

- **DoseEvent** — 一次给药事件（路由、时间、剂量、酯别、附加字段如凝胶面积或贴片释放速率）。
- **ParameterResolver** — 将事件映射为 `PKParams`（$k_1$/$k_2$/$k_3$、$F$、双库比例、零阶速率等）。
- **ThreeCompartmentModel** — 解析解工具箱：三室模型、单室 Bateman、双通路舌下模型、贴片零阶/一阶模型。
- **SimulationEngine** — 预编译各给药事件为"时间 $\to$ 药量"函数，逐点线性叠加，换算浓度，梯形法积分 AUC。

### 1.2 给药途径简表

| 路由 | 模型 | 关键参数 | $F$ 来源 | 浓度单位 |
|---|---|---|---|---|
| 注射（EB/EV/EC/EN） | 双库三室 | $k_{1f}, k_{1s}, k_2, k_3$ | formationFraction | pg/mL |
| 贴片（E2） | 皮肤储库双室 | rateMGh / $k_1$, $k_{\text{skin}}$, $k_3$ | 1.0 | pg/mL |
| 凝胶（E2） | 单室 Bateman | $k_1 = 0.022$, $F = 0.05$ | 常量 | pg/mL |
| 口服（E2） | 单室 Bateman | $k_a = 0.32$, $F = 0.03$ | 常量 | pg/mL |
| 口服（EV） | 单室 Bateman | $k_a = 0.05$, $F = 0.03$ | 常量 | pg/mL |
| 舌下（E2） | 双通路 Bateman | $\theta$, $k_{SL}$, $k_{abs}$ | 快 1.0 / 慢 0.03 | pg/mL |
| 舌下（EV） | 双通路混合 | $\theta$, $k_{SL}$, $k_{abs}$, $k_2$ | 快 1.0 / 慢 0.03 | pg/mL |
| 口服（CPA） | 单室 Bateman | $k_a = 0.35$, $F = 0.88$ | 常量 | ng/mL |

---

## 2 变量与单位

- 剂量 `doseMG` 以 mg 计；中心室药量计算单位也是 mg。
- 输入剂量均已按 E2 等效（E2-eq）换算，`EsterInfo.toE2Factor` 仅用于显示。
- E2 浓度输出 pg/mL：

$$C_{E2}\ [\text{pg/mL}] = \frac{A\ [\text{mg}] \times 10^9}{V_d\ [\text{mL}]}$$

- CPA 浓度输出 ng/mL：

$$C_{CPA}\ [\text{ng/mL}] = \frac{A\ [\text{mg}] \times 10^6}{V_d\ [\text{mL}]}$$

- 体分布体积：$V_d = v_{d,\text{perKG}} \times BW$。E2: $v_{d,\text{perKG}} = 2.0$ L/kg；CPA: $v_{d,\text{perKG}} = 20.6$ L/kg。

---

## 3 酯别与分子量

| 酯别 | 全称 | MW (g/mol) | toE2Factor |
|---|---|---:|---|
| E2 | Estradiol | 272.38 | 1.000 |
| EB | Estradiol Benzoate | 376.50 | 0.7233 |
| EV | Estradiol Valerate | 356.50 | 0.7641 |
| EC | Estradiol Cypionate | 396.58 | 0.6868 |
| EN | Estradiol Enanthate | 384.56 | 0.7084 |
| CPA | Cyproterone Acetate | 416.94 | — |

其中 $\text{toE2Factor} = M_{E2} / M_{\text{ester}} = 272.38 / M_{\text{ester}}$（CPA 不适用）。

---

## 4 生物利用度

### 4.1 注射油剂（formationFraction）

注射路由的有效生物利用度定义为：

$$F = \texttt{formationFraction}[\text{ester}] \times \text{toE2Factor}$$

| 酯别 | formationFraction | 说明 |
|---|---:|---|
| EB | 0.10922 | 经验标定值 |
| EV | 0.06226 | 经验标定值 |
| EC | 0.11726 | 经验标定值 |
| EN | 0.12000 | 经验标定值 |

### 4.2 其他路由

| 路由 | $F$ | 说明 |
|---|---:|---|
| 贴片 | 1.0 | 剂量已折算为系统暴露 |
| 凝胶 | 0.05 | 经皮系统暴露分数 |
| 口服（E2/EV） | 0.03 | 首过后系统暴露，文献 5% (0.1–12%) [^13] |
| 舌下快支 | 1.0 | 绕过首过 |
| 舌下慢支 | 0.03 | 等同口服 |
| CPA 口服 | 0.88 | 文献 88 ± 20% [^17] |

---

## 5 核心 PK 参数

### 5.1 E2 参数

| 参数 | 含义 | 值 | 备注 |
|---|---|---:|---|
| $v_{d,\text{perKG}}$ | 表观分布容积 | 2.0 L/kg | 可配置 [^14] |
| $k_{\text{clear}}$ | 游离 E2 清除速率 $k_3$ | 0.41 h⁻¹ | $t_{1/2} \approx 1.69$ h |
| $k_{\text{clear,inj}}$ | 注射专用 $k_3$ | 0.041 h⁻¹ | $t_{1/2} \approx 16.9$ h，有效参数 |
| $k_{1,\text{corr}}$ | 注射 $k_1$ 全局校正 | 1.0 | 可缩放注射吸收速率 |

#### $k_{\text{clear}}$ 锚点说明

$k_{\text{clear}} = 0.41$ h⁻¹ 的锚点来自游离 E2 的真实血浆清除速率，对应 $t_{1/2} \approx 1.69$ h。该值在贴片、凝胶、口服与舌下路由中用作中心室消除常数 [^7][^9][^10]。

> **注意**：贴片移除后的表观半衰期（5.9–7.7 h，Vivelle-Dot FDA Label [^22]）远长于 1.69 h。这是因为皮肤储库室在贴片移除后仍持续排空，其转运速率 $k_{\text{skin}} = 0.10$ h⁻¹（$t_{1/2} \approx 6.93$ h）主导了表观消除。此前版本直接用 $k_{\text{clear}}$ 拟合移除后衰减，导致衰减过快。

#### $k_{\text{clear,inj}}$（注射有效参数）

注射油剂的末端斜率受从油性贮库进入血液的缓慢输入所支配（flip-flop）。为在简化模型中复现文献级别的 $T_{\max}$/$C_{\max}$，注射路径使用 $k_{\text{clear,inj}} = 0.041$ h⁻¹（$t_{1/2} \approx 16.9$ h）[^2]。它是形状校准的有效参数，并不等同于生理清除。仅在 `route == .injection` 时使用。

### 5.2 CPA 参数

| 参数 | 含义 | 值 | 文献值 | 来源 |
|---|---|---:|---|---|
| $v_{d,\text{perKG}}$ | 分布容积 | 20.6 L/kg | 20.6 ± 3.5 | [^15][^16] |
| $k_a$ | 口服吸收速率 | 0.35 h⁻¹ | $T_{\max}$ 1.6–3.7 h | [^15] |
| $k_{el}$ | 消除速率 | 0.017 h⁻¹ | $t_{1/2}$ 38–53 h | [^18] |
| $F$ | 口服生物利用度 | 0.88 | 68–100% | [^17] |
| MW | 分子量 | 416.94 g/mol | 416.94 | [^16] |

---

## 6 数学模型

### 6.1 三室解析解

三室串联模型：吸收（$k_1$）→ 酯水解（$k_2$）→ 游离 E2 清除（$k_3$）。中心室（游离 E2）药量：

$$A(t) = D \cdot F \cdot k_1 \cdot k_2 \left[\frac{e^{-k_1 t}}{(k_1 - k_2)(k_1 - k_3)} + \frac{e^{-k_2 t}}{(k_2 - k_1)(k_2 - k_3)} + \frac{e^{-k_3 t}}{(k_1 - k_3)(k_2 - k_3)}\right]$$

对应代码 `ThreeCompartmentModel._analytic3C`。当任意两个速率常数接近时（差 $< 10^{-9}$）返回 0 以避免除零。

### 6.2 单室 Bateman

经典一室吸收-消除模型：

$$A(t) = \frac{D \cdot F \cdot k_a}{k_a - k_e} \left( e^{-k_e t} - e^{-k_a t} \right)$$

当 $|k_a - k_e| < 10^{-9}$ 时取极限形式：$A(t) = D \cdot F \cdot k_a \cdot t \cdot e^{-k_e t}$。

对应代码 `ThreeCompartmentModel._batemanAmount`。

### 6.3 贴片皮肤储库模型

经皮给药的限速步骤是角质层扩散 [^13]。药物从贴片释放后先进入皮肤储库（角质层 + 真皮层），再经毛细血管进入血液循环。模型结构为：

$$\text{Patch} \xrightarrow{R \text{ 或 } k_1} \text{Skin Depot} \xrightarrow{k_{\text{skin}}} \text{Plasma} \xrightarrow{k_3} \text{Elimination}$$

其中 $k_{\text{skin}} = 0.10$ h⁻¹（$t_{1/2} \approx 6.93$ h），拟合 Vivelle-Dot 移除后表观 $t_{1/2} = 5.9$–$7.7$ h [^22]。代码中复用 `PKParams.k2` 字段传递此参数。

#### 6.3.1 零阶输入

佩戴期（$0 \le t \le T_{\text{wear}}$），皮肤储库 $S$ 与血浆 $P$ 满足：

$$\frac{dS}{dt} = R - k_{\text{skin}} \cdot S, \quad \frac{dP}{dt} = k_{\text{skin}} \cdot S - k_3 \cdot P$$

解析解（令 $\Delta k = k_3 - k_{\text{skin}}$）：

$$S(t) = \frac{R}{k_{\text{skin}}} \left(1 - e^{-k_{\text{skin}} t}\right)$$

$$P(t) = \frac{R}{k_3} \left[1 - \frac{k_3}{\Delta k} e^{-k_{\text{skin}} t} + \frac{k_{\text{skin}}}{\Delta k} e^{-k_3 t}\right]$$

稳态 $P_{\text{ss}} = R / k_3$，不受 $k_{\text{skin}}$ 影响。90% 稳态时间由慢指数项 $e^{-k_{\text{skin}} t}$ 控制：$T_{90\%} \approx 2.3 / k_{\text{skin}} \approx 23$ h，与文献 $T_{\max}$ 12–36 h 一致 [^22][^23]。

移除后（$\delta t = t - T_{\text{wear}}$），令 $S_{\text{rem}} = S(T_{\text{wear}})$，$P_{\text{rem}} = P(T_{\text{wear}})$：

$$P(\delta t) = \frac{S_{\text{rem}} \cdot k_{\text{skin}}}{\Delta k} \left(e^{-k_{\text{skin}} \cdot \delta t} - e^{-k_3 \cdot \delta t}\right) + P_{\text{rem}} \cdot e^{-k_3 \cdot \delta t}$$

第一项表示皮肤储库持续排空对血浆的贡献。由于 $k_3 \gg k_{\text{skin}}$，表观消除半衰期 $\approx \ln 2 / k_{\text{skin}} \approx 6.93$ h。

对应代码 `ThreeCompartmentModel._patchZeroOrder`。

#### 6.3.2 一阶输入

佩戴期直接使用三室解析解（贴片释放 $k_1$ → 皮肤储库 $k_{\text{skin}}$ → 清除 $k_3$）：

$$P(t) = D \cdot F \cdot k_1 \cdot k_{\text{skin}} \left[\frac{e^{-k_1 t}}{(k_1 - k_{\text{skin}})(k_1 - k_3)} + \frac{e^{-k_{\text{skin}} t}}{(k_{\text{skin}} - k_1)(k_{\text{skin}} - k_3)} + \frac{e^{-k_3 t}}{(k_1 - k_3)(k_{\text{skin}} - k_3)}\right]$$

即 `_analytic3C(k1=kRelease, k2=kSkin, k3=kEl)`。

移除后，计算移除时刻的皮肤储库残留量 $S_{\text{rem}}$ 与血浆量 $P_{\text{rem}}$，使用与零阶相同的双室衰减公式。

对应代码 `ThreeCompartmentModel._patchFirstOrder`。

#### 6.3.3 后备行为

当 $k_{\text{skin}} = 0$ 时（`PKParams.k2 == 0`），两个函数自动退化为旧版单室模型，保持向后兼容。

### 6.4 双通路模型

#### 双通路 Bateman (`dualAbsAmount`)

两支路均用单室 Bateman：

$$A(t) = A_{\text{fast}}(t) + A_{\text{slow}}(t)$$

其中 $D_{\text{fast}} = \theta \cdot D$，$D_{\text{slow}} = (1-\theta) \cdot D$，各支路的 $F$ 和 $k_1$ 分别指定。

用于舌下 E2（$k_2 = 0$，无水解步）。

#### 双通路混合 (`dualAbsMixedAmount`)

快支用三室解析解，慢支用单室 Bateman：

$$A(t) = A^{(3C)}_{\text{fast}}(t) + A^{(\text{Bat})}_{\text{slow}}(t)$$

用于舌下 EV（$k_2 > 0$，进血后需水解为 E2）。快支走 `_analytic3C`（吸收 → 水解 → 清除），慢支走 `_batemanAmount`（吸收 → 清除，水解已折叠进更低的 $k_a$）。

---

## 7 给药途径

### 7.1 注射油剂（EB/EV/EC/EN）

**模型**：两并联"库"吸收 → 酯水解 → 清除 [^2][^6]。"快库"控制 $T_{\max}$/$C_{\max}$，"慢库"控制尾相。

**参数表**：

| 酯 | $f_{\text{fast}}$ | $k_{1f}$ (h⁻¹) | $t_{1/2,f}$ (h) | $k_{1s}$ (h⁻¹) | $t_{1/2,s}$ (h) | $k_2$ (h⁻¹) | $t_{1/2,hyd}$ (h) |
|---|---:|---:|---:|---:|---:|---:|---:|
| EB | 0.90 | 0.144 | 4.81 | 0.114 | 6.08 | 0.090 | 7.70 |
| EV | 0.40 | 0.0216 | 32.08 | 0.0138 | 50.23 | 0.070 | 9.90 |
| EC | 0.229 | 0.00504 | 137.66 | 0.00451 | 153.67 | 0.045 | 15.40 |
| EN | 0.05 | 0.0010 | 693.15 | 0.0050 | 138.63 | 0.015 | 46.21 |

注射路径清除常数 $k_3 = k_{\text{clear,inj}} = 0.041$ h⁻¹。

**代码路径**：`ParameterResolver.resolve(.injection)` → `ThreeCompartmentModel.injAmount`。

### 7.2 贴片（E2）

**模型**：皮肤储库双室模型 — 贴片 → 皮肤储库 → 血浆 → 清除 [^7][^8][^9][^22][^23]。

角质层充当药物储库，是经皮吸收的限速步骤 [^13]。皮肤储库转运速率 $k_{\text{skin}} = 0.10$ h⁻¹（$t_{1/2} \approx 6.93$ h），由 Vivelle-Dot 移除后表观 $t_{1/2} = 5.9$–$7.7$ h 拟合得到 [^22]。

**参数表**：

| 参数 | 值 | 说明 | 来源 |
|---|---:|---|---|
| $k_{\text{skin}}$ | 0.10 h⁻¹ | 皮肤→血浆转运速率 | Vivelle-Dot FDA Label [^22] |
| $k_1$ | 0.0075 h⁻¹ | 一阶贴片释放速率 | 经验值 |
| $k_3$ | 0.41 h⁻¹ | 游离 E2 清除 | 同非注射路由 |
| $F$ | 1.0 | 剂量已折算为系统暴露 | — |

两种输入方式 [^7][^8][^9]：

1. **零阶输入**：当事件带 `releaseRateUGPerDay` 时，按标称 μg/day 转 mg/h 注入皮肤储库，经 $k_{\text{skin}}$ 转运至血浆。移除后皮肤储库持续排空，表观 $t_{1/2} \approx 6.93$ h。详见 §6.3.1。
2. **一阶近似**（遗留）：若未提供标称释放率，用 $k_1 = 0.0075$ h⁻¹ 经三室解析解（$k_1 \to k_{\text{skin}} \to k_3$）建模。详见 §6.3.2。

佩戴窗口 = `patchApply` 到后续 `patchRemove` 之间的时长。

**代码路径**：`ParameterResolver.resolve(.patchApply)` → `ThreeCompartmentModel.patchAmount` → `_patchZeroOrder` / `_patchFirstOrder`。

### 7.3 经皮凝胶（E2）

单室一阶吸收 + 清除 [^1]。当前为稳定起见使用常量参数：

- $k_1 = 0.022$ h⁻¹（$t_{1/2} \approx 31.5$ h）
- $F = 0.05$

暂不考虑涂抹面积与剂量密度的非线性。

**代码路径**：`ParameterResolver.resolve(.gel)` → `ThreeCompartmentModel.oneCompAmount`。

### 7.4 口服（E2/EV）

单室 Bateman 吸收–清除 [^5][^11]。EV 的水解效应已折叠进更小的 $k_a$，不单独建 $k_2$。

| 参数 | E2 | EV | 说明 |
|---|---:|---:|---|
| $k_a$ | 0.32 h⁻¹ | 0.05 h⁻¹ | 吸收速率 |
| $F$ | 0.03 | 0.03 | 口服首过后系统暴露 |
| $k_3$ | 0.41 h⁻¹ | 0.41 h⁻¹ | 游离 E2 清除 |

口服 EV 还额外使用 $k_2(\text{EV}) = 0.070$ h⁻¹（酯水解常数），但在 `ParameterResolver` 中此值仅传入参数结构体，oneCompAmount 函数本身不使用 $k_2$。

**代码路径**：`ParameterResolver.resolve(.oral)` → `ThreeCompartmentModel.oneCompAmount`。

### 7.5 舌下（E2/EV）

#### 双通路分流

剂量按分流系数 $\theta$ 分为两支 [^3]：

- **快通路**（口腔黏膜）：$k_{1,\text{fast}} = k_{\text{SL}} = 1.8$ h⁻¹，绕过首过，$F_{\text{fast}} = 1.0$。
- **慢通路**（吞咽 → 胃肠）：$k_{1,\text{slow}} = k_a$（E2: 0.32 h⁻¹，EV: 0.05 h⁻¹），$F_{\text{slow}} = 0.03$。

**E2 vs EV 差异**：

- 舌下 E2：$k_2 = 0$，用 `dualAbsAmount`（两支路均为单室 Bateman）。
- 舌下 EV：$k_2 = 0.070$ h⁻¹，用 `dualAbsMixedAmount`（快支三室，慢支 Bateman）。

清除 $k_3 = 0.41$ h⁻¹（非注射路由）。

#### 黏膜分流 $\theta$ 的行为建模

默认 $\theta = 0.025$，校准自 Doll et al. (2021, PMID 34781041) [^25]：n=10 跨性别女性（BMI 33±13），1mg 微粉化 17β-E2 舌下含服（含到完全溶解，约 2 分钟），LC-MS/MS Cmax = 144 ± 90 pg/mL（基线 24 ± 8 pg/mL），Tmax = 1h，AUC(0-8h) 为口服的 1.8 倍。用户可通过自定义 $\theta$ 覆盖此默认值。

显式建模溶解与吞咽清除，将口腔视为最小系统：固体剂量 $S$ 以速率 $k_{\text{diss}}$ 溶入口腔液相 $D$；$D$ 面临黏膜吸收 $k_{\text{SL}}$ 与吞咽清除 $k_{\text{sw}}$ 的竞争。

$$\begin{aligned}\frac{dS}{dt} &= -k_{\text{diss}} \, S \\\frac{dD}{dt} &= k_{\text{diss}} \, S - (k_{\text{SL}} + k_{\text{sw}}) \, D\end{aligned}$$

在含服窗口 $T_{\text{hold}}$ 内，实际经黏膜的比例为：

$$\theta(T_{\text{hold}}) = \frac{1}{\text{Dose}} \int_0^{T_{\text{hold}}} k_{\text{SL}} \, D(t) \, dt$$

超过 $T_{\text{hold}}$ 的残留一律视为吞咽，进入口服通道。

**参数锚点**：$k_{\text{SL}} = 1.8$ h⁻¹（由舌下 E2 实测 $T_{\max} \approx 1$ h 反推 [^3]）。

#### 自定义 $\theta$ 参考档位

| 档位 | 建议含服时长 | $\theta$ 参考 | 范围 |
|---|---:|---:|---|
| Quick | 2 min | 0.01 | 0.004–0.012 |
| Casual | 5 min | 0.04 | 0.021–0.057 |
| Standard | 10 min | 0.11 | 0.064–0.156 |
| Strict | 15 min | 0.18 | 0.115–0.253 |

#### 一致性验证

当 $\theta = 0$ 时，舌下模型严格退化为口服：慢支的 $k_{1,\text{slow}}$、$F_{\text{slow}}$、$k_2$、$k_3$ 与口服路由完全一致，全轨迹差异为 0。

---

## 8 CPA 模型（醋酸环丙孕酮）

### 8.1 概述

醋酸环丙孕酮 (CPA) 是一种抗雄激素/孕激素药物，常见于跨性别 HRT 方案 [^19]。本模型对 CPA 口服途径实现了独立的单室 Bateman PK 建模，输出浓度单位为 ng/mL（区别于 E2 的 pg/mL）。

### 8.2 数学模型

采用单室 Bateman 口服模型：

$$A(t) = \frac{D \cdot F \cdot k_a}{k_a - k_{el}} \left( e^{-k_{el} t} - e^{-k_a t} \right)$$

浓度换算：

$$C_{\text{CPA}}\ [\text{ng/mL}] = \frac{A\ [\text{mg}] \times 10^6}{v_{d,\text{perKG}} \times BW \times 1000}$$

### 8.3 参数表

| 参数 | 值 | 文献值 | 来源 |
|---|---:|---|---|
| $v_{d,\text{perKG}}$ | 20.6 L/kg | 20.6 ± 3.5 L/kg | PMID 2977383 [^15] |
| $k_a$ | 0.35 h⁻¹ | $T_{\max}$ 1.6–3.7 h | [^15] |
| $k_{el}$ | 0.017 h⁻¹ | $t_{1/2}$ 38–53 h | PMID 9349934 [^18] |
| $F$ | 0.88 | 68–100% | PMID 880829 [^17] |

### 8.4 SimulationEngine 中的 E2/CPA 分离

`SimulationEngine` 在初始化时将给药事件按酯别分为 E2 事件与 CPA 事件两组，分别使用各自的 $V_d$ 计算浓度。E2 使用 $v_{d,\text{perKG}} = 2.0$ L/kg，CPA 使用 $v_{d,\text{perKG}} = 20.6$ L/kg。模拟结果同时输出 `concPGmL`（E2）和 `concNGmL_CPA`（CPA）两条曲线。

**代码路径**：`ParameterResolver.resolve(.oral, .CPA)` → `ThreeCompartmentModel.oneCompAmount`。

---

## 9 模拟流程与 AUC

`SimulationEngine.run()` 的执行步骤：

1. 按均匀时间网格（`numberOfSteps` 个点）遍历 $[\text{startTimeH}, \text{endTimeH}]$。
2. 对每个时间点，累加所有 E2 事件的药量，再除以 $V_d$（mL）乘以 $10^9$ 得 pg/mL。
3. CPA 事件类似，乘以 $10^6$ 得 ng/mL。
4. AUC 使用梯形法则对浓度轨迹积分（单位 pg·h/mL 或 ng·h/mL）。

模型为线性系统（常数 $k_3$），重复给药时叠加自然收敛至稳态。

**注意**：由于部分参数为经验标定，AUC 的绝对值在不同路由间比较时需谨慎，适合作为同一路由内的相对比较与个体内优化。

---

## 10 实验室校准（Lab Calibration）

### 10.1 概述

实验室校准功能允许用户输入真实血检结果，自动校正模拟浓度曲线。

- **输入**：一组 `LabResult`（时间戳 + 实测浓度 pg/mL）与对应的模拟结果 `SimulationResult`。
- **输出**：校准后的浓度数组 `[Double]`，与模拟时间网格一一对应。

### 10.2 校准点构建

对每条血检结果，计算校准比值：

$$r_i = \frac{C_{\text{obs},i}}{C_{\text{sim},i}}$$

过滤条件：
- $C_{\text{obs},i} > 0$（观测值为正）
- $C_{\text{sim},i} \ge 1.0$ pg/mL（模拟值不能过低，防止比值失真）

限界：$r_i \in [0.01, 100.0]$。

对应代码 `LabCalibration.buildCalibrationPoints`。

### 10.3 IDW + 时间衰减插值

给定一组校准点 $\{(t_i, r_i)\}$，在任意时刻 $t$ 的校准比值 $r(t)$ 由逆距离加权（IDW）+ 指数时间衰减计算：

$$w_i = \frac{\exp(-\text{age}_i / \tau)}{\max(|t - t_i|,\, \varepsilon)^p}$$

$$r(t) = \frac{\sum_i w_i \cdot r_i}{\sum_i w_i}$$

其中：

| 参数 | 含义 | 值 |
|---|---|---:|
| $\text{age}_i$ | 时间距离 $|t - t_i|$（秒） | — |
| $\tau$ | 衰减时间常数 | $30 \times 86400$ s（30 天） |
| $p$ | IDW 幂次 | 2 |
| $\varepsilon$ | 最小距离（防除零） | 3600 s（1 小时） |

**边界行为**：

- 单点时直接返回该 ratio。
- $t$ 精确命中某点时直接返回该点 ratio。
- 外推时最近校准点权重最大（IDW 距离项主导），随距离增大权重迅速衰减。
- 最终结果限界 $r(t) \in [0.01, 100.0]$。

对应代码 `LabCalibration.calibrationRatio(at:points:)`。

### 10.4 校准浓度

$$C_{\text{cal}}(t) = C_{\text{sim}}(t) \times r(t)$$

仅校准 E2 浓度曲线。

对应代码 `LabCalibration.calibratedConcentration(sim:labResults:)`。

### 10.5 代码路径

`LabCalibration.buildCalibrationPoints` → `LabCalibration.calibrationRatio` → `LabCalibration.calibratedConcentration`

---

## 11 局限

- 个体差异未建模：肝功能、SHBG、年龄、体脂、并用药等可能改变 $F$ 与各速率常数。
- 凝胶的面积/负荷非线性：当前未在模型中体现。
- 注射溶剂/体积影响：对扩散 $k_1$ 的影响尚未显式参数化，现仅可用 $k_{1,\text{corr}}$ 近似。
- 口服/舌下仅建模游离 E2：雌酮及其硫酸酯的储库效应未纳入。
- AUC 的跨路由可比性有限：参数含经验缩放。

---

## 参考文献

[^1]: mtf.wiki. 雌二醇凝胶. [https://mtf.wiki/zh-cn/docs/medicine/estrogen/gel](https://mtf.wiki/zh-cn/docs/medicine/estrogen/gel)
[^2]: Transfem Science. Injectable estradiol meta-analysis. [https://transfemscience.org/articles/injectable-e2-meta-analysis/](https://transfemscience.org/articles/injectable-e2-meta-analysis/)
[^3]: Transfem Science. Sublingual estradiol overview. [https://transfemscience.org/articles/sublingual-e2-transfem/](https://transfemscience.org/articles/sublingual-e2-transfem/)
[^4]: Transfem Science. Approximate comparable doses. [https://transfemscience.org/articles/e2-equivalent-doses/](https://transfemscience.org/articles/e2-equivalent-doses/)
[^5]: Transfem Science. Oral vs. transdermal estradiol. [https://transfemscience.org/articles/oral-vs-transdermal-e2/](https://transfemscience.org/articles/oral-vs-transdermal-e2/)
[^6]: estrannai.se. Ingredients and algorithms. [https://estrannai.se/docs/ingredients/](https://estrannai.se/docs/ingredients/)
[^7]: Climara (estradiol transdermal system) FDA label. Bayer.
[^8]: FDA NDA clinical pharmacology review — estradiol transdermal.
[^9]: FDA label (2008) — estradiol transdermal system.
[^10]: Ginsburg ES et al. Half-life of estradiol in postmenopausal women. *Fertil Steril*. 1998. PMID 9473164.
[^11]: Kuhl H. Pharmacology of estrogens and progestogens. *Climacteric*. 2005. PMID 16112947.
[^12]: Oinonen KA et al. Absorption and bioavailability of oestradiol. *Eur J Pharm Biopharm*. 1999. PMID 10465378.
[^13]: Wikipedia. Pharmacokinetics of estradiol. [https://en.wikipedia.org/wiki/Pharmacokinetics_of_estradiol](https://en.wikipedia.org/wiki/Pharmacokinetics_of_estradiol)
[^14]: DrugBank. Estradiol (DB00783). [https://go.drugbank.com/drugs/DB00783](https://go.drugbank.com/drugs/DB00783)
[^15]: Wikipedia. Pharmacology of cyproterone acetate. [https://en.wikipedia.org/wiki/Pharmacology_of_cyproterone_acetate](https://en.wikipedia.org/wiki/Pharmacology_of_cyproterone_acetate)
[^16]: DrugBank. Cyproterone acetate (DB04839). [https://go.drugbank.com/drugs/DB04839](https://go.drugbank.com/drugs/DB04839)
[^17]: Humpel M et al. Bioavailability and pharmacokinetics of CPA. *Contraception*. 1977. PMID 880829.
[^18]: Barradell LB, Faulds D. Cyproterone: a review of its pharmacology. 1994. PMID 9349934.
[^19]: Coleman E et al. WPATH Standards of Care v8. *Int J Transgender Health*. 2022. PMID 36238954.
[^20]: HRT-Recorder-PKcomponent-Test. GitHub. [https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test](https://github.com/LaoZhong-Mihari/HRT-Recorder-PKcomponent-Test)
[^21]: Mahiro. Estrogen model summary. [https://mahiro.uk/articles/estrogen-model-summary](https://mahiro.uk/articles/estrogen-model-summary)
[^22]: Vivelle-Dot (estradiol transdermal system) FDA label (2014, NDA 020538). Post-removal t½ = 5.9–7.7 h; Tmax ≈ 24–36 h; Cmax (0.1 mg/day) ≈ 117 pg/mL. [https://www.accessdata.fda.gov/drugsatfda_docs/label/2014/020538s032lbl.pdf](https://www.accessdata.fda.gov/drugsatfda_docs/label/2014/020538s032lbl.pdf)
[^23]: Climara Pro (estradiol/levonorgestrel transdermal system) FDA label (2005, NDA 021885). Dose-proportional PK; steady-state by 2nd application cycle. [https://www.accessdata.fda.gov/drugsatfda_docs/label/2005/021885lbl.pdf](https://www.accessdata.fda.gov/drugsatfda_docs/label/2005/021885lbl.pdf)
[^24]: Dose proportionality of Estradot. *Maturitas* 2003. Inter-individual variability 20–44%. [https://doi.org/10.1016/S0378-5122(03)00189-0](https://doi.org/10.1016/S0378-5122(03)00189-0)
[^25]: Doll EE et al. Pharmacokinetics of sublingual versus oral estradiol in transgender women. *Transgend Health*. 2021. PMID 34781041.
