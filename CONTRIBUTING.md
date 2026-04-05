# Contributing

Style notes for this code.

## **Code Philosophies**

| Acronym | Full Name | Core Concept |
| :--- | :--- | :--- |
| **COI** | **Composition Over Inheritance** | Use "part-of" (composition) rather than "is-a" (inheritance). |
| **SSOT** | **Single Source of Truth** | All config is derived from a single help string. |
| **ZIP** | **Compressed Profile** | Maximize logic per screen; minimize whitespace. |
| **BOB** | **Big On Brevity** | Aim for functions of 5 lines or less. |
| **KISS** | **Keep It Simple, Stupid** | One function, one specific job, zero fluff. |
| **BAIL** | **Bail Early** | Use one-line guard clauses to exit functions immediately. |
| **GAP** | **Signature Gap** | Use 4 spaces to separate arguments from locals in signatures. |
| **HINT** | **Type Hinting** | Variable names act as explicit type hints. |


## **The Meta-Rule: The Casing Trinity**

We use casing to distinguish between the class, its constructor, and its instances:
* **`SHOUT_CASE`**: The **Class/Container** (e.g., `NUM`, `DATA`). Holds methods.
* **`PascalCase`**: The **Constructor** (e.g., `Num()`, `Data()`). Creates the object.
* **`camelCase`**: The **Instance** (e.g., `num`, `data`). The variable in use.


## **Construction List**

### **Core Primitives & Instances**
* **`i`**: Reserved strictly for **self** in method signatures. Never use for integers.
* **`n`**: Used for **integers**, counts, or indices.
* **`s` / `v`**: Generic **string** / Generic **scalar value**.
* **`fn` / `ok`**: **Function** callback / **Boolean** success flag.
* **`num` / `sym`**: Instances of `NUM` or `SYM`.
* **`data` / `node`**: Instances of `DATA` or `TREE`.
* **`col` / `cut`**: A column object / A split (partition) object.

### **Collections (Plurals)**
Pluralization (trailing `s` or doubled characters) indicates a table or list:
* **`ss` / `vs`**: List of **strings** / List of **values**.
* **`cols` / `rows`**: List of **column objects** / List of **data rows**.
* **`xs` / `ys`**: List of **feature columns** / List of **goal columns**.

### **Contextual Hints**
* **`at`**: The specific index/offset (e.g., `col.at` in a row).
* **`err`**: Residuals, distances, or deltas.
* **`lo` / `hi`**: Numeric boundaries.
* **`mu` / `sd`**: Raw Mean and Standard Deviation.


## **Geometry & Layout**

* **Indentation & Width**: 2 spaces; max 90 characters.
* **The Lonely End Rule**: Never leave `end` on its own line if it can be joined to the line before.
    * `function Tree(score) return new(TREE, {score=score}) end`
* **Density**: Use semicolons (`;`) to pack related statements and prefer boolean shortcuts (`and/or`).
    * `if v~="?" then i:add(v,w or 1) end; return v`
* **Signatures (GAP)**: Use a 4-space break to separate inputs from internal locals. For multiple locals, use no spaces between them.
    * `function mink(vs,     err,n)`
* **Localization**: All standalone functions (constructors, helpers, stats) must be `local` for speed and encapsulation.


## **Object Orientation & Commenting**

* **COI over Inheritance**: Group methods by **Action/Lifecycle Stage**, not by Class. Stack methods with the same name to highlight the functional contract (Polymorphism).
* **Lifecycle Grouping**:
    1. **Structs**: Constructors.
    2. **Update**: Methods changing state (e.g., `add`, `sub`).
    3. **Query**: Methods returning calculations (e.g., `mid`, `spread`).
* **Minimalist Tags**: Use short action headers like `-- ## update ---` to separate stages.

