# SIH26038: Explainable AI for Diabetic Retinopathy Screening in Rural India
## Complete System Architecture, Mathematical Algorithms, Preprocessing, CNN Backbone & Decision Workflow

---

## 1. Executive Summary & Clinical Context

### 1.1 Problem Statement & Challenge (SIH 2026 - PS 26038)
Diabetic Retinopathy (DR) is a severe microvascular complication of diabetes mellitus leading to irreversible vision loss and blindness if not diagnosed and treated early. In rural India, regular retinal screening of diabetic populations faces severe structural barriers:
- **Massive Caseload vs. Specialist Deficit**: Millions of diabetic patients are registered at Primary Health Centres (PHCs) and Community Health Centres (CHCs), but ophthalmologists and trained retinal graders are concentrated in urban tertiary hospitals.
- **Asymptomatic Early Stages**: Microaneurysms and subtle intraretinal microvascular abnormalities can only be detected via digital fundus photography.
- **The Grader Fatigue Problem**: ~60% of all screened fundus photographs in general diabetic cohorts show no retinopathy (healthy retina). Human ophthalmologists spend valuable clinical hours confirming normal retinas rather than treating sight-threatening disease.
- **The "Black-Box" AI Dilemma**: Standard deep neural networks produce opaque probability scores without clinical justification. If an AI misclassifies a proliferative case as normal, a patient goes blind without recourse. Furthermore, purely binary classifiers force uncertain cases into automated decisions.

### 1.2 The Project Mission & Philosophy
Built for **MathWorks / MATLAB**, `SIH26038` provides an explainable, safe, and deployable end-to-end AI screening pipeline designed specifically for rural tele-ophthalmology camps and PHCs.

Key governing principles:
1. **Three-Way Clinical Disposition**: The system outputs **Auto-Clear**, **Refer**, or **Escalate**.
   - *Auto-Clear*: Confident normal eye; patient is safely scheduled for routine annual rescreening without occupying specialist time.
   - *Refer*: Confident referable diabetic retinopathy; referral slip printed for tertiary care evaluation.
   - *Escalate*: First-class clinical deferral. If image quality is poor, evidence disagrees, uncertainty is high, or proliferative signs exist, the system declines automated disposition and routes the image to human expert review.
2. **Dual-Channel Independent Evidence**: A deep learning classification backbone (ResNet-50) is cross-checked against independent lesion evidence (both classical morphological operators and a multi-label deep segmentation U-Net).
3. **Visual & Clinical Explainability**: Decisions are backed by high-resolution **Grad-CAM** attention maps, detected lesion masks, quadrant-based lesion distributions, and a formal rule trace adhering to the **International Clinical Diabetic Retinopathy (ICDR)** standard.
4. **Safety Veto & Equal-Coverage Admissibility**: A configuration is medically inadmissible if it sends more referable patients home than the classifier alone at the same autonomous coverage.
5. **Rigorous Data Discipline**: Sealed external test evaluation (Messidor-2), patient-level stratified splitting, fixed operating points, and calibrated probabilities via temperature scaling.

---

## 2. End-to-End Screening Pipeline Workflow

The complete end-to-end inference lifecycle of a single retinal fundus image is orchestrated via `app.runScreeningCase` through an 8-stage pipeline:

```
                  +-------------------------------+
                  |      Input Fundus Image       |
                  +---------------+---------------+
                                  |
                                  v
                  +-------------------------------+
                  |  Stage 1: Quality Gate        |
                  |  - FOV Mask & Metrics         |
                  |  - Focus, Exposure, Contrast  |
                  +---------------+---------------+
                                  |
            +---------------------+---------------------+
            |                                           |
    [Ungradable]                                   [Gradable /
            |                                      Borderline Enhanced]
            v                                           |
+-----------------------+                               v
| Immediate Escalation  |               +-------------------------------+
| Recapture Advice Sent |               | Stage 2: Shared Preprocessing |
+-----------------------+               | - FOV Crop & CLAHE            |
                                        | - 448x448 Bicubic Resize      |
                                        | - Zero-Mean Normalization     |
                                        +---------------+---------------+
                                                        |
                                +-----------------------+-----------------------+
                                |                                               |
                                v                                               v
                +-------------------------------+               +-------------------------------+
                | Stage 3: CNN Grading Backbone |               | Stage 5: Lesion Evidence      |
                | - ResNet-50 (448x448x3)       |               | - Track A: Top-Hat Candidates |
                | - Logits Generation           |               | - Track B: U-Net Segmentation |
                +---------------+---------------+               |   (Hard Exudates Trusted Head)|
                                |                               +---------------+---------------+
                                v                                               |
                +-------------------------------+                               |
                | Stage 4: Calibration & GradCAM|                               |
                | - Temperature Scaling (T=2.14)|                               |
                | - Calibrated P(referable)     |                               |
                | - Grad-CAM Layer 'activation_'|                               |
                +---------------+---------------+                               |
                                |                                               |
                                +-----------------------+-----------------------+
                                                        |
                                                        v
                                        +-------------------------------+
                                        | Stage 6: ICDR Rule Engine     |
                                        | - Microaneurysm Counts        |
                                        | - 4-Quadrant Lesion Rules     |
                                        | - Reachable Level Analysis    |
                                        +---------------+---------------+
                                                        |
                                                        v
                                        +-------------------------------+
                                        | Stage 7: Agreement & Policy   |
                                        | - Spatial Gate (GradCAM vs L) |
                                        | - Endpoint Referral Agreement |
                                        | - Three-Way Triage Evaluation |
                                        +---------------+---------------+
                                                        |
                                                        v
                                        +-------------------------------+
                                        | Stage 8: Report & UI Delivery |
                                        | - Interactive App Canvas      |
                                        | - Provenance-Signed Report    |
                                        +-------------------------------+
```

---

## 3. Detailed Component Analysis & Mathematical Algorithms

### 3.1 Stage 1: Retinal Image Quality Assessment (`+quality`)
Before computational resources are expended on deep networks, fundus captures must pass an automated quality gate. Ungradable images (common in rural camps due to cataract, uncooperative patients, pupil constriction, or camera defocus) cause deep learning models to hallucinate false positives or miss subtle lesions.

#### 3.1.1 Field-of-View (FOV) Segmentation (`quality.fovMask`)
Retinal cameras produce a circular illuminated aperture inside a black rectangular frame:
1. Grayscale luminance $I_{gray}$ is extracted.
2. Background threshold is estimated using Otsu's method combined with morphological opening.
3. Morphological closing with a large structuring element (`strel('disk', R)`) fills dark retinal vessels and optical disc shadows.
4. Active mask $M_{FOV}$ is retained; boundary bright ring artifacts from optical flash reflection are clipped.

#### 3.1.2 Quantitative Quality Features (`quality.qualityFeatures`)
Features are strictly computed **inside the FOV mask only** ($p \in M_{FOV}$):
1. **Focus / Sharpness**:
   - *Variance of Laplacian*:
     $$\Delta I = \nabla^2 I_{green} = \frac{\partial^2 I}{\partial x^2} + \frac{\partial^2 I}{\partial y^2}$$
     $$\text{VarLap} = \frac{1}{|M_{FOV}|} \sum_{p \in M_{FOV}} \left( \Delta I(p) - \mu_{\Delta I} \right)^2$$
   - *Tenengrad Gradient Magnitude*:
     $$G_x = I * S_x, \quad G_y = I * S_y \quad (\text{Sobel kernels})$$
     $$\text{Tenengrad} = \sum_{p \in M_{FOV}} \left( G_x(p)^2 + G_y(p)^2 \right)$$
2. **Illumination & Exposure**:
   - *Mean Intensity*: $\mu = \frac{1}{|M|} \sum I(p)$
   - *Dark Pixel Fraction*: Fraction of pixels where $I(p) \le 0.08$.
   - *Saturated Pixel Fraction*: Fraction of pixels where $I(p) \ge 0.95$.
   - *Quadrant Illumination Variation*: The retinal background is estimated via Gaussian smoothing with $\sigma = 30$:
     $$I_{bg} = I_{green} * G_\sigma$$
     FOV is partitioned into 4 quadrants. The standard deviation across the 4 quadrant mean intensities normalized by the mean assesses uneven flash illumination or vignetting.
3. **Contrast & Information Entropy**:
   - *RMS Contrast*: Root-mean-square intensity variation across the retina.
   - *Shannon Entropy*: $H = - \sum_{k=0}^{255} P(k) \log_2 P(k)$.

#### 3.1.3 Quality Triage & Recapture Advice (`quality.classifyQuality`, `quality.recaptureAdvice`)
- **Gradable**: Clear macula, visible vascular arcade, sharp optic disc.
- **Borderline**: Slight non-uniform illumination or mild defocus. Sent to deterministic enhancement.
- **Ungradable**: Severe underexposure/overexposure, extreme blur, or FOV area ratio $< 0.20$.
- **Actionable Operator Advice**: If rejected, operator is directly informed:
  - `"Increase illumination; image is severely underexposed."`
  - `"Adjust camera diopter focus; optical blur detected."`
  - `"Re-center patient eye; aperture truncated."`

#### 3.1.4 Borderline Image Enhancement (`quality.enhanceBorderline`)
Enhancement is deterministic and strictly confined to borderline captures:
1. **Illumination Correction**:
   $$I_{norm}(x, y) = I_{green}(x, y) - I_{bg}(x, y) + \bar{I}_{bg}$$
2. **Rayleigh Contrast-Limited Adaptive Histogram Equalization (CLAHE)**:
   - Tile grid: $8 \times 8$.
   - Clip limit: $0.01$ (strictly bounded to prevent sensor noise amplification into pseudo-microaneurysms).
   - Rayleigh target distribution to maintain natural retinal contrast.
3. **Conservative Denoising**:
   - Non-Local Means filter (`imnlmfilt`) preserves vessel margins while smoothing background sensor grain.

---

### 3.2 Stage 2: Unified Preprocessing Pipeline (`+common/preprocess.m`)
A primary failure mode in applied medical AI is **training-serving skew** (different normalization or cropping between training code and production inference). In this repository, **exactly one preprocessing function exists**: `common.preprocess`.

1. **Precision & Type Casting**: Inputs are cast to single-precision floating point $\in [0.0, 1.0]$.
2. **FOV Crop**: Bounding box of $M_{FOV}$ is identified:
   $$[x_{min}, y_{min}, \text{width}, \text{height}] = \text{bbox}(M_{FOV})$$
   Image is cropped strictly to the retinal disc boundary, eliminating redundant black margins.
3. **Spatial Normalization**: Cropped retina is rescaled to exactly $448 \times 448 \times 3$ via high-order **bicubic interpolation**. 
   - *Critical Design Rule*: Resolutions $\le 224 \times 224$ destroy microaneurysms (which often occupy only $2 \times 2$ to $4 \times 4$ pixels at native capture). $448 \times 448$ is the proven lower bound.
4. **Channel Normalization**:
   $$I_{model}^{(c)} = \frac{I_{crop}^{(c)} - \mu^{(c)}}{\sigma^{(c)}}, \quad c \in \{R, G, B\}$$
   Matches pretrained backbone expectations.

---

### 3.3 Stage 3: Deep Learning Grading Backbone (`+grade/train.m`, `+grade/infer.m`)

#### 3.3.1 Network Architecture
The classification backbone is an adapted **ResNet-50** deep convolutional neural network:
- **Input Dimension**: $448 \times 448 \times 3$.
- **Feature Extractor**: 53 deep convolutional layers comprising bottleneck residual blocks:
  $$y = \mathcal{F}(x, \{W_i\}) + x$$
  Captures hierarchical retinal patterns: low-level edges, vascular branches, cotton-wool spot textures, and macro-hemorrhages.
- **Classification Head Adaptation**:
  - Pretrained ImageNet fully-connected layer `fc1000` is removed.
  - Global Average Pooling: `avg_pool` outputs a 2048-dimensional feature vector.
  - **Regularization**: A dedicated `dropoutLayer(0.5, 'Name', 'head_dropout')` is inserted. (Standard ResNet-50 ships with 0% dropout; experiments in this repo demonstrated severe memorization on APTOS without dropout).
  - Dense Projection: 5-class linear layer outputting raw logits $z = [z_0, z_1, z_2, z_3, z_4]^T$ representing the 5 ICDR severity levels:
    - **Grade 0**: No Apparent Retinopathy
    - **Grade 1**: Mild Non-Proliferative DR (NPDR)
    - **Grade 2**: Moderate NPDR
    - **Grade 3**: Severe NPDR
    - **Grade 4**: Proliferative DR (PDR)

#### 3.3.2 Training Strategy & Loss Function
- **Data Augmentation (`augmentBatch.m`)**:
  - Random affine rotations $\theta \in [-180^\circ, +180^\circ]$ (retinal fundus is rotationally symmetric).
  - Horizontal & vertical flips.
  - Scale jitter: $[0.85, 1.0]$.
  - Brightness shifts $\pm 10$ and contrast gain $[0.9, 1.1]$.
- **Class Balancing**: APTOS exhibits severe class imbalance (Grade 0 constitutes $>50\%$ of cases, Grade 4 is $<5\%$).
  - Two-tier mitigation: Minority oversampling + Inverse-frequency class weights in the loss:
    $$w_c = \frac{N}{K \cdot N_c}$$
    $$\mathcal{L}_{CE} = - \sum_{c=0}^4 w_c \cdot y_c \log(\text{softmax}(z_c))$$
- **Optimization**:
  - **Optimizer**: Adam ($\beta_1 = 0.9, \beta_2 = 0.999, \epsilon = 10^{-8}$).
  - **Two-Phase Warmup**:
    - *Epochs 1–2*: Convolutional backbone frozen; only the custom classification head is trained with learning rate $\eta = 10^{-3}$.
    - *Epochs 3–15*: Entire network un-frozen for fine-tuning at $\eta = 2 \times 10^{-5}$ with weight decay $\lambda = 0.1$.
    - *Gradient Clipping*: $L_2$-norm gradient threshold capped at $10.0$ to prevent exploding gradients.
- **Validation Discipline**: Full per-class recall and confusion matrices are logged at every epoch. Checkpoint selection is strictly based on **Macro Recall**, not overall accuracy.

---

### 3.4 Stage 4: Probability Calibration & Explainability (`+grade/applyTemperature.m`, `+explain/gradcam.m`)

#### 3.4.1 Temperature Scaling (Platt Scaling Extension)
Raw softmax outputs from deep networks are notoriously overconfident and cannot be interpreted as true posterior probabilities $P(Y | X)$.
To transform raw logits $z \in \mathbb{R}^5$ into calibrated probabilities:
$$p_i(T) = \frac{\exp(z_i / T)}{\sum_{j=0}^4 \exp(z_j / T)}$$
- Temperature parameter $T > 0$ is fitted on a held-out **Calibration Split** ($n=365$) by minimizing Negative Log-Likelihood (NLL):
  $$\min_T - \sum_{k=1}^{n} \log\left( p_{y^{(k)}}(T) \right)$$
- Optimal fitted temperature: **$T = 2.1414$** (indicating substantial raw model overconfidence).
- **Calibrated Referable Risk Metric**:
  $$P(\text{referable}) = \sum_{c=2}^4 p_c(T) = p_2(T) + p_3(T) + p_4(T)$$
- Operating Point: Fixed threshold **$\tau_{refer} = 0.40$**.
  - Validation Sensitivity: **0.9821** (95% Wilson CI: 0.956–0.993)
  - Validation Specificity: **0.9174** (95% Wilson CI: 0.881–0.943)

#### 3.4.2 Visual Saliency via Grad-CAM
To verify that ResNet-50 bases its predictions on pathological anatomy rather than camera artifacts:
1. Target class $c$ is selected (predicted ICDR level).
2. Forward pass extracts activation maps $A^k \in \mathbb{R}^{U \times V}$ from the final convolutional block (`activation_49_relu`).
3. Backpropagation computes gradients of score $y^c$ w.r.t feature map $A^k$:
   $$\alpha_k^c = \frac{1}{U \cdot V} \sum_{i=1}^U \sum_{j=1}^V \frac{\partial y^c}{\partial A_{i, j}^k}$$
4. Class-specific Grad-CAM heatmap is formed:
   $$L_{\text{Grad-CAM}}^c = \text{ReLU}\left( \sum_k \alpha_k^c A^k \right)$$
5. The low-resolution map ($14 \times 14$) is upsampled to the original image dimensions ($H \times W$), normalized to $[0, 1]$, and superimposed with a jet colormap onto the fundus photograph.

---

### 3.5 Stage 5: Dual-Channel Lesion Detection & Segmentation (`+segment`)
Grad-CAM heatmaps highlight general retinal regions of interest, but they lack discrete lesion grounding. To prevent confirmation bias, the pipeline incorporates **two independent lesion detection channels**:

#### 3.5.1 Track A: Classical Morphological Channel (`segment.detectMicroaneurysmCandidates`)
A training-free classical computer vision pipeline targeting microaneurysms (MAs—the earliest hallmark of DR):
1. **Inverted Green Channel**: In retinal imaging, hemoglobin absorbs green light ($540\text{–}570\text{ nm}$), making retinal vessels and hemorrhages darkest in the green channel. Inverting yields bright spots on dark background:
   $$I_{inv} = 1 - I_{green}$$
2. **Multi-Scale Morphological Top-Hat Filtering**:
   - Compact circular disk top-hat:
     $$T_{disk}(x) = \max_{r \in \{2, 3, 4\}} \left( I_{inv} - (I_{inv} \circ B_r^{disk}) \right)$$
   - Directional linear top-hats across 12 orientations $\theta \in [0^\circ, 165^\circ]$:
     $$T_{linear}(x) = \min_{\theta, L} \left( I_{inv} - (I_{inv} \circ B_{\theta, L}^{line}) \right)$$
3. **Vessel Suppression via Infimum**:
   $$R(x) = \min\left( T_{disk}(x), T_{linear}(x) \right)$$
   *Mathematical Principle*: A circular microaneurysm remains bright under top-hat transforms of all angles. A linear blood vessel gets smoothed out by at least one matching linear structuring element; taking the minimum suppresses vascular branches while preserving punctate microaneurysms.
4. **Candidate Extraction**:
   - Thresholding at $R \ge \tau_{resp}$.
   - Area filtering: $4 \le \text{Area} \le 120\text{ px}$.
   - Vessel skeleton proximity masking.

#### 3.5.2 Track B: Learned Multi-Label Lesion Segmentation U-Net (`segment.trainLesionSegmentation`, `segment.segmentLesions`)
Classical detectors can only detect MAs (capping evidence at ICDR Level 1). To reach Levels 2 and 3, a deep convolutional U-Net was trained on native-resolution crops of **IDRiD Set-A**:
- **Architecture**:
  - Encoder: 4 stages, base filters = 32 ($32 \to 64 \to 128 \to 256$, bridge = 512).
  - Double convolutional blocks: Conv3x3 $\to$ BatchNorm $\to$ ReLU $\to$ Conv3x3 $\to$ BatchNorm $\to$ ReLU.
  - Decoder: Transposed convolutions (stride 2) + Skip concatenation + Double Conv3x3 blocks.
  - Multi-Head Output: $1 \times 1$ Convolution emitting 4 logit maps:
    1. **MA**: Microaneurysms
    2. **HE**: Hemorrhages
    3. **EX**: Hard Exudates (lipid leakage)
    4. **SE**: Soft Exudates / Cotton-Wool Spots (ischemia)
- **Patch Sampling on Native Resolution**:
  - Resizing large fundus images ($4288 \times 2848$) to $512 \times 512$ erases microaneurysms!
  - Therefore, training uses native $512 \times 512$ crops with **75% lesion-centered patch sampling**.
- **Asymmetric Focal Tversky Loss (`segment.lesionLoss`)**:
  Lesion pixels constitute only $0.1\%$ to $1.0\%$ of fundus pixels. Symmetric losses (Dice/BCE) achieve 99.5% accuracy by simply predicting background everywhere.
  $$TI_c = \frac{\sum p_{c} g_{c} + \epsilon}{\sum p_{c} g_{c} + \alpha \sum p_{c} (1 - g_{c}) + \beta \sum (1 - p_{c}) g_{c} + \epsilon}$$
  $$\mathcal{L}_{FTL} = \sum_{c=1}^4 \left( 1 - TI_c \right)^{1 / \gamma}$$
  - Parameters: $\alpha = 0.3$, **$\beta = 0.7$** (strictly weighting false negatives above false positives; $\beta > \alpha$ is enforced by invariant assertions), $\gamma = 2.0$.
- **The Domain Transfer Discovery (IDRiD $\to$ APTOS)**:
  When transferring to the broader APTOS dataset:
  - Soft Exudate head exhibited false positives on healthy retinas, dropping specificity to 0.00.
  - **Trusted Head Policy**: Analysis proved that isolating **Hard Exudates (EX)** at threshold $0.99$ restores specificity to **0.8257** and validation sensitivity to **0.8072**, providing rock-solid Level 2 evidence.

#### 3.5.3 Vessel Segmentation Baseline (DRIVE U-Net)
- Trained on DRIVE dataset (128x128 patches, CLAHE green channel).
- Uses symmetric **Combined Dice + BCE Loss** (`vesselLoss.m`), because blood vessels occupy 12.5% of the retina (100x higher prevalence than lesions).
- Evaluated strictly inside FOV mask (avoiding false background inflation from black corners). ROC AUC = 0.9621 on held-out test.

---

### 3.6 Stage 6: The Clinical ICDR Rule Engine (`+grade/icdrRule.m`)
Medical AI must adhere to established clinical protocols. The rule engine translates raw lesion detections into standard **ICDR 0–4** clinical severity levels completely independent of the CNN:

```
                  +-----------------------------------+
                  |      Lesion Evidence Input        |
                  +-----------------+-----------------+
                                    |
            +-----------------------+-----------------------+
            |                                               |
  [Neovascularisation?                              [No Proliferative
   Preretinal Hemorrhage?]                           Findings]
            |                                               |
         (YES)                                              v
            |                               +-------------------------------+
            v                               | 4-2-1 Rule:                   |
    +---------------+                       | - >20 Hemorrhages in all 4 Qs |
    | ICDR Level 4  |                       | - Venous Beading >= 2 Qs      |
    | Proliferative |                       | - Prominent IRMA >= 1 Q       |
    +---------------+                       +---------------+---------------+
                                                            |
                                        +-------------------+-------------------+
                                        |                                       |
                                     (YES)                                     (NO)
                                        |                                       |
                                        v                                       v
                                +---------------+               +-------------------------------+
                                | ICDR Level 3  |               | Non-Microaneurysm Lesions?    |
                                | Severe NPDR   |               | (Hard Exudates / Hemorrhages) |
                                +---------------+               +---------------+---------------+
                                                                                |
                                                                +---------------+---------------+
                                                                |                               |
                                                             (YES)                             (NO)
                                                                |                               |
                                                                v                               v
                                                        +---------------+               +---------------+
                                                        | ICDR Level 2  |               | Microaneurysms|
                                                        | Moderate NPDR |               | Only?         |
                                                        +---------------+               +-------+-------+
                                                                                                |
                                                                                +---------------+---------------+
                                                                                |                               |
                                                                             (YES)                             (NO)
                                                                                |                               |
                                                                                v                               v
                                                                        +---------------+               +---------------+
                                                                        | ICDR Level 1  |               | ICDR Level 0  |
                                                                        | Mild NPDR     |               | No Retinopathy|
                                                                        +---------------+               +---------------+
```

#### Diagnostic Partitioning: Capability Gaps vs. Case-Level Unknowns
A critical architectural contribution of this system is differentiating why evidence is missing:
- **Capability Gap**: A detector for a specific clinical feature (e.g. *neovascularisation* or *venous beading*) does not exist in this software build. It is unknown for *every* image. Escalating on a capability gap would shut down autonomous screening entirely (100% escalation). Hence, capability gaps are transparently stated in the report disclosures but **do not force escalation**.
- **Case-Level Unknown**: A detector exists, but failed on *this specific image* (e.g. optic disc occluded, vessel mask corrupted). This is an unpredictable patient-level hazard and **forces immediate escalation**.

---

### 3.7 Stage 7: Agreement Check & The Three-Way Decision Policy (`+grade/decisionPolicy.m`)
The final triage decision is governed by explicit safety gates that synthesize the CNN prediction, calibration, Grad-CAM attention, and lesion evidence.

#### 3.7.1 The Grad-CAM Spatial Agreement Gate (`grade.spatialEvidence`, `grade.spatialVerdict`)
Does the neural network's visual attention align with physical lesion candidates?
- Let $\{ (x_k, y_k) \}_{k=1}^K$ be the detected lesion candidate coordinates.
- Let $H_{norm}(x, y) \in [0, 1]$ be the normalized Grad-CAM heatmap.
- **The Spatial Criterion**:
  $$\text{Cleared Fraction} = \frac{1}{K} \sum_{k=1}^K \mathbb{I}\left( H_{norm}(x_k, y_k) \ge \tau_{cut} \right)$$
  $$\text{Agree} \iff \text{Cleared Fraction} \ge \tau_{frac}$$
  - Frozen configuration parameters: $\tau_{cut} = 0.35$, $\tau_{frac} = 0.25$.
- **Clinical Validation of the Gate**:
  In validation split analysis, an erroneous CNN baseline missed 4 referable patients (calling them Level 0 or 1 with confident low risk). One of them (`d1a24527a15d`) was a **severe proliferative case (Grade 4)**. 
  The Grad-CAM spatial gate fired at 100% strength ($0\%$ of candidates reached attention), stopping this catastrophic miss and escalating the patient to an ophthalmologist! Retaining this gate is codified under **ADR 0002**.

#### 3.7.2 Endpoint Comparison vs. Exact Level Comparison
- *Old Policy (Exact Match)*: Required $\text{Level}_{CNN} == \text{Level}_{Rule}$. If CNN predicted Level 0 and Rule Engine saw Level 1 (both non-referable), the case escalated, collapsing coverage to 6.9%.
- *Adopted Policy (Endpoint Match - A10)*:
  $$\left( \text{Level}_{CNN} \ge 2 \right) \iff \left( \text{Level}_{Rule} \ge 2 \right)$$
  Comparing on the primary referral boundary restored autonomous coverage to **32.73%** while sending **0 referable patients home**.

#### 3.7.3 Formal Three-Way Decision Logic
1. **MANDATORY ESCALATION TRIGGERS (Safety Exceptions)**:
   - Quality is `ungradable` or unenhanced `borderline`.
   - Any `case-level unknown` in clinical evidence.
   - CNN predicted **Grade 4 (Proliferative)**: `alwaysEscalateLevel4 = true` (Proliferative cases carry imminent blindness risk and must always be examined by a human retina specialist).
   - Spatial disagreement: $\text{Cleared Fraction} < 0.25$.
   - Under-detection: CNN predicts referable ($\ge 2$), but lesion evidence channel finds zero lesions.
   - Over-detection: Lesion evidence channel finds clear referable lesions, but CNN predicts non-referable ($< 2$).
   - High Bayesian/predictive uncertainty ($U > 0.50$).

2. **AUTO-CLEAR CONDITIONS** (Patient sent home with annual follow-up):
   - Zero safety exceptions.
   - $P(\text{referable}) < 0.40$ (`autoClearThreshold`).
   - Predicted Level $< 2$.
   - Rule engine confirms non-referable (Level 0 or 1).
   - Agreement status is `concordant`.

3. **REFER CONDITIONS** (Specialist referral slip printed):
   - Zero safety exceptions.
   - $P(\text{referable}) \ge 0.70$ (`referableThreshold`).
   - Predicted Level $\ge 2$.
   - Lesion evidence confirms presence of referable lesions.
   - Agreement status is `concordant`.

---

## 4. Empirical Benchmarks, Ablations & Validations

### 4.1 Frozen Operating Point (Dated 2026-08-23)
- **Dataset**: APTOS 2019 Blindness Detection (Patient-stratified splits: Train = 2564, Val = 550, Cal = 365, Test = 383).
- **Referable Threshold**: $\tau = 0.40$
- **Validation Sensitivity**: **0.9821** (95% Wilson Interval: 0.9547–0.9932)
- **Validation Specificity**: **0.9174** (95% Wilson Interval: 0.8825–0.9427)

### 4.2 Lesion Segmentation Benchmark (Held-out IDRiD Set-B, $n=27$)
Evaluated across 33 evenly spaced thresholds over pooled pixels:

| Lesion Type | Precision-Recall AUPR | Prevalence | Relative Lift (AUPR / Prev) |
| :--- | :---: | :---: | :---: |
| **Microaneurysms (MA)** | 0.4340 | 0.00098 | **442x** |
| **Hemorrhages (HE)** | 0.2060 | 0.01066 | **19x** |
| **Hard Exudates (EX)** | 0.7550 | 0.01085 | **70x** |
| **Soft Exudates (SE)** | 0.0980 | 0.00181 | **54x** |
| **Mean Multi-Lesion** | **0.3732** | — | — |

### 4.3 Pipeline Ablation Study (Validation Split, $n=550$)

| Configuration | Evidence Channel | Spatial Gate | Level Match | Autonomous Coverage | Autonomous Accuracy | Referable Sent Home | ADR 0001 Admissible? |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A1 (CNN Only Baseline)** | None | None | None | 100.0% | 0.9436 | 4 | Baseline |
| **A5 (Shipped v1)** | Classical (MA) | Gate | Exact | 27.45% | 0.9934 | 1 | No |
| **A9 (Learned Heads)** | EX (0.99) | Gate | Exact | 6.91% | 0.9474 | 0 | Yes |
| **A10 (Shipped Current)**| **EX (0.99)** | **Gate** | **Endpoint**| **32.73%** | **0.9889** | **0** | **YES (Optimal)** |
| **A11 (Spatial Advisory)**| EX (0.99) | Advisory | Exact | 24.36% | 0.9552 | 2 | No |
| **A12 (Both Repairs)** | EX (0.99) | Advisory | Endpoint | 66.36% | 0.9836 | 2 | No (Vetoed) |
| **A14 (Prob Cut Alone)** | None | None | None | 75.27% | 0.9855 | 1 (Grade 4!) | No (Lacks Explainability) |

*Key Conclusion*: **A10 is the only admissible non-trivial configuration**. It delivers zero false negatives (0 referable patients sent home), preserves the lifesaving spatial gate, and expands autonomous coverage to one-third of all rural visits.

---

## 5. District Tele-Ophthalmology Capacity Simulation (`simulink/`)

Beyond algorithmic accuracy, the repository includes a full discrete-event simulation in **MATLAB Simulink / SimEvents** (`simulink/district_model.slx`) modeling the health logistics of an entire Indian district (100,000 diabetic screenings/year):

### 5.1 Infrastructure & Queueing Parameters
- **Arrival Processes**: Poisson arrival with seasonal/weekly camp-day surges (camp days produce $4\times$ peak patient queue bursts).
- **Edge vs. Cloud Telemedicine Constraint**:
  - Telemedicine in rural India is bottlenecked by **connectivity availability**, not raw bandwidth.
  - At 30% internet window availability, uploading 8 MB raw images to cloud servers causes multi-hour backlogs.
  - Local edge inference resolves decisions in seconds, transferring only lightweight triage summaries.
- **Grader Capacity & Workload**:
  - At the deployed A10 deferral rate (67.27% escalation), total human ophthalmologist workload across 100,000 patients is **591.82 grader-hours/year**.
  - A single dedicated district specialist working standard shifts easily clears the entire deferred caseload within the 24-hour clinical turnaround target.

---

## 6. User Interface, Clinical Reports & Developer Operations

### 6.1 ScreeningApp UI (`app/ScreeningApp.m`)
The demonstration interface is built entirely in native MATLAB App Designer code:
- **Design System**: Modern Light Glassmorphism theme with high-contrast typography and Dark Pro toggle.
- **Visual Viewport**: 4 simultaneous diagnostic axes:
  1. *Original Fundus Capture*
  2. *Preprocessed / Enhanced Retina*
  3. *Grad-CAM Visual Saliency Overlay*
  4. *Detected Lesion Morphology Mask*
- **Verdict & Risk Strip**: Immediate visual indication of Auto-Clear (Green), Refer (Amber/Red), or Escalate (Blue/Grey) alongside calibrated percentage risk.
- **Stage Progression Indicators**: Real-time pipeline status lights from Quality Gate to Decision Policy.
- **Quick Preset Selector**: Preloaded real validation cases representing all clinical edge conditions.

### 6.2 CLI Entry Points & Shell Orchestration (`start.sh`)
The entire platform is automated via `start.sh`:
```bash
# Launch the interactive MATLAB demo app:
./start.sh

# Run headless single-image screening demo with full decision trace:
./start.sh demo

# Display frozen operating point constants and verified metrics:
./start.sh numbers

# Run the complete headless test suite (100% pass required):
./start.sh tests

# Run environment and data preflight checks:
./start.sh check
```

---

## 7. Repository Layout & Engineering Standards

```
sih26038-master/
├── config/                  # Frozen JSON configurations (default.json, ablations A1..A13)
├── data/
│   ├── splits/              # Patient-level stratified CSV splits (train, val, calib, test)
│   ├── raw/                 # Local image archives (APTOS, IDRiD, DRIVE)
│   ├── sealed/              # Sealed Messidor-2 test set (Unread during development)
│   └── PROVENANCE.md        # Cryptographic SHA-256 hashes of all raw datasets
├── src/
│   ├── +common/             # Shared preprocessing (single source of truth)
│   ├── +quality/            # Quality assessment, FOV masking, borderline enhancement
│   ├── +grade/              # ResNet-50 grading, temperature scaling, ICDR rules, decision policy
│   ├── +explain/            # Multi-layer Grad-CAM generator, lesion candidate mapper
│   ├── +segment/            # Morphological detector, U-Net multi-lesion & vessel segmentation
│   ├── +report/             # Automated PDF/HTML clinical report generator
│   └── +app/                # Pipeline orchestrator (runScreeningCase.m)
├── app/                     # ScreeningApp.m (Glassmorphism UI class) and demo assets
├── simulink/                # district_model.slx and capacity sweep experiments E1..E6
├── eval/                    # Evaluation harnesses, Wilson confidence metrics, ablation scripts
├── tests/                   # Automated MATLAB unit test suite (matlab.unittest)
├── docs/                    # SIH26038_design.html (Source of truth), ADRs, clinical protocols
└── start.sh                 # Unified shell controller
```

### 7.1 Strict Coding Invariants
- **Deterministic Re-runnability**: Every script and entry point sets `rng(42, 'twister')`.
- **Immutable Results Directory**: Outputs are saved to dated directories under `results/` containing the exact copy of the config used; nothing is ever overwritten.
- **Headless Compatibility**: All MATLAB routines run cleanly in `matlab -batch` without requiring X11 desktop windows.
- **Separation of Concerns**: Clinical decisions are made by transparent rules, deep networks are used solely as feature and probability extractors, and safety checks cannot be bypassed.
