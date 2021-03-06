---
categories:
- translation
- blockchain
- tutorial
comments: true
date: 2018-05-26T00:00:00Z
tags:
- blockchain
- transaction
title: "[Go로 구현하는 블록체인] Part 4: 트랜잭션 1"
url: /building-blockchain-in-go-part-4
---

> [Building Blockchain in Go](https://jeiwan.cc/posts/building-blockchain-in-go-part-4) 시리즈를 번역한 글입니다.

# 서론

트랜잭션은 비트코인의 핵심이며 블록체인의 유일한 목적은 트랜잭션을 안전하고 신뢰할 수 있는 방식으로 저장하는 것이기 때문에 트랜잭션이 한 번 생성되면 그 누구도 이를 수정할 수 없다. 이번 파트에서는 트랜잭션을 구현할 것이다. 그러나 이는 꽤 큰 주제이기 때문에 두 파트로 나누었다. 이 파트에서는 일반적인 트랜잭션 메커니즘을 구현하며, 두 번째 파트에서는 좀 더 자세한 내용을 다룰 것이다.

코드의 수정사항 또한 많기 때문에 여기서 모든 코드를 보여주진 않는다. 전체 코드 수정사항은 [여기](https://github.com/Jeiwan/blockchain_go/compare/part_3...part_4#files_bucket)에서 볼 수 있다.

# 숟가락은 없다 (There is no spoon)

웹 애플리케이션을 개발해봤다면 결제 기능을 구현하기 위해 DB에 **accounts**와 **transactions**라는 테이블을 생성해봤을 것이다. account는 개인정보와 잔고를 포함하는 유저 정보를 저장하며 transactions는 계좌간 이체 정보를 저장한다. 비트코인에서는 결제를 완전히 다른 방식으로 구현하고있다. 비트코인에는

1. 계좌가 없다.
2. 잔고가 없다.
3. 주소가 없다.
4. 코인이 없다.
5. 송수신자가 없다.

블록체인은 공개된 데이터베이스이기 때문에 지갑 소유자에 대한 민감한 정보는 저장하지 않는다. 코인은 계좌에 수집되지 않으며, 트랜잭션은 한 주소에서 다른 주소로 돈을 이체하지 않는다. 또한 계좌 잔고를 저장하는 필드나 속성값 또한 없다. 오로지 트랜잭션만이 존재한다. 그렇다면 트랜잭션 안에는 어떤 정보가 저장될까?

# 비트코인 트랜잭션

트랜잭션은 입력과 출력의 조합이다.

```go
type Transaction struct {
        ID   []byte
        Vin  []TXInput
        Vout []TXOutput
}
```

새로운 트랜잭션의 입력은 이전 트랜잭션의 출력을 참조한다 (예외도 존재하지만 이는 나중에 살펴볼 것이다). 출력은 코인이 실제로 저장되는 곳이다. 다음 다이어그램은 트랜잭션간의 상호연결을 보여준다.

![Transaction Diagram](../images/2018-05-26-transactions-diagram.png)

위 다이어그램에서 다음을 볼 수 있다.

1. 입력과 연결되지 않은 출력이 존재한다.
2. 한 트랜잭션의 입력은 여러 트랜잭션의 출력을 참조할 수 있다.
3. 입력은 반드시 출력을 참조해야한다.

이 글에서 우리는 "돈 (money)", "코인 (coins)", "소비 (spend)", "전송 (send)" 그리고 "계좌 (account)"등과 같은 용어를 사용할 것이다. 그러나 비트코인에는 이러한 개념들이 없다. 트랜잭션은 스크립트를 사용해 값을 잠그기만 하며, 스크립트로 잠근 사람만 잠금을 해제할 수 있다.

# 트랜잭션 출력

트랜잭션 출력부터 살펴보자.

```go
type TXOutput struct {
        Value        int
        ScriptPubKey string
}
```

실제로 이 출력은 "코인"을 저장한다 (**Value** 필드를 보아라). 그리고 저장이란 **ScriptPubKey**에 저장되어있는 암호로 값을 잠그는 것을 의미한다. 비트코인은 내부적으로 출력 잠금과 로직 해제를 정의하는데 사용되는 *Script*라는 스크립팅 언어를 사용한다. 이 언어는 아주 원시적이지만 (해킹과 잘못된 사용을 피하기위해 의도된 설계이다), 여기서 자세히 논의하지는 않는다. 자세한 설명은 [여기](https://en.bitcoin.it/wiki/Script)에서 볼 수 있다.

> 비트코인에서 *값 (value)* 필드는 BTC의 개수가 아닌 *사토시 (satoshis)*의 개수를 저장한다. *사토시 (satoshis)*는 1억분의 1 비트코인 (0.00000001 BTC)이며 비트코인의 최소 화폐 단위이다 (센트와 유사하다).

현재는 구현된 주소가 없기 때문에 이와 관련된 전체 로직을 스크립팅하진 않을 것이다. **ScriptPubKey**는 임의의 문자열을 저장한다 (사용자 정의 지갑 주소).

> 그런데, 스크립팅 언어를 가지고 있다는건 비트코인 또한 스마트 컨트랙트 플랫폼으로 사용될 수 있음을 의미한다.

출력에 대한 중요한점 중 하나는 분리가 불가능하다는 것이다. 즉, 값의 일부만 참조할 수는 없다는 의미이다. 출력이 새로운 트랜잭션에서 참조되면 출력의 전체가 모두 소비된다. 그리고 이 값이 필요한 값보다 큰 경우에는, 잔액이 만들어지며 이는 보낸 사람에게 다시 전송된다. 이는 실생활에서 $1의 물건을 구매하기위해 $5를 지불하면 $4의 잔액이 남는 상황과 유사하다.

# 트랜잭션 입력

입력 구조체는 다음과 같다.

```go
type TXInput struct {
        Ixid      []byte
        Vout      int
        ScriptSig string
}
```

이전에도 언급했듯이 입력은 이전 출력을 참조한다. **Txid**는 해당 트랜잭션의 ID를 저장하고 **Vout**은 트랜잭션의 출력 인덱스를 저장한다. **ScriptSig**는 출력의 **ScriptPubKey**에서 사용되는 데이터를 제공하는 스크립트이다. 데이터가 올바르면 출력의 잠금을 해제할 수 있으며 출력의 값 (Value)을 사용해 새로운 출력을 생성할 수 있다. 그렇지 않은 경우에 해당 출력은 입력에서 참조할 수 없다. 이 메커니즘은 사용자가 다른 사람들이 소유한 코인을 사용할 수 없음을 보장해준다.

또 다시, 현재는 구현된 주소가 없기 때문에 **ScriptSig**는 임의의 사용자 정의 지갑 주소를 저장할 것이다. 퍼블릭 키와 시그니처 검증은 다음 파트에서 구현할 것이다.

이제 내용을 요약해보자. "코인"은 출력에 저장된다. 각 출력에는 잠금 해제 로직을 결정하는 잠금 해제 스크립트가 함께 제공된다. 모든 새로운 트랜잭션은 반드시 적어도 하나의 입력과 출력을 가진다. 입력은 이전 트랜잭션의 출력을 참조하고 잠금 해제를 위해 출력의 잠금 해제에 사용되는 데이터 (**ScriptSig** 필드)를 제공하며 이 값을 사용해 새로운 출력을 생성한다.

그런데 어떤게 먼저일까? 입력? 출력?

# 달걀

비트코인에서는 닭보다 달걀이 먼저다. 입출력 로직은 고전적인 "닭이 먼저냐 달걀이 먼저냐"의 문제와 같다. 입력이 출력을 생성하고 출력은 입력을 가능하게한다. 그리고 비트코인에서는 입력보다 출력이 먼저다.

채굴자가 블록 채굴을 시작하면 이는 **코인베이스 트랜잭션**에 추가된다. 코인베이스 트랜잭션은 특수한 타입의 트랜잭션으로 이전 출력을 요구하지 않는다. 이는 아무것도 없는 상태에서 ("코인"등의) 출력을 생성한다. 닭 없는 달걀인 것이다. 이는 채굴자가 새로운 블록을 채굴할 때 받는 보상이다.

여러분도 알듯이 블록체인의 시작 부분에는 제네시스 블록이 있다. 이 블록이 바로 블록체인에서 최초의 출력을 생성하는 블록이다. 그리고 이 블록에는 이전 트랜잭션이 존재하지 않으며  그에 따른 출력도 없기 때문에 이전 출력을 요구하지 않는다.

코인베이스 트랜잭션을 만들어보자.

```go
func NewCoinbaseTX(to, data string) *Transaction {
        if data == "" {
                data = fmt.Sprintf("Reward to '%s'", to)
        }
        txin := TXInput([]byte{}, -1, data)
        txout := TXOutput{subsidy, to}
        tx := Transaction{nil, []TXInput{txin}, []TXOutput{txout}}
        tx.SetID()
        return &tx
}
```

코인베이스 트랜잭션은 단 하나의 입력만 가진다. 우리의 구현체에서 이 입력의 **Txid**는 비어있으며 **Vout**은 -1이다. 또한 코인베이스 트랜잭션은 **ScriptSig**에 아무 스크립트도 저장하지 않으며 대신 임의의 데이터가 저장된다.

> 비트코인의 최초의 코인베이스 트랜잭션에는 다음과 같은 메시지가 담겨있다. "The Times 03/Jan/2009 Chancellor on brink of second bailout for banks". [여기에서 직접 확인할 수 있다](https://blockchain.info/tx/4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b?show_adv=true)
> **subsidy**는 보상의 양이다. 비트코인에서 이 숫자는 그 어느 곳에도 저장되어있지 않으며 총 블록 수를 기준으로 계산된다. 블록의 수는 **210000**으로 나누어 떨어진다. 제네시스 블록을 채굴하면 50 BTC가 생성되며 매 **210000** 블록마다 보상이 반으로 줄어든다. 우리는 이 보상을 상수로 둘 것이다 (적어도 지금은😉).

# 블록체인에 트랜잭션 저장하기

지금부터 모든 블록은 적어도 하나의 트랜잭션을 가지며 더 이상 트랜잭션 없이 블록을 채굴하는건 불가능하다. 이는 **Block** 필드에서 **Data** 필드를 제거하고 대신 트랜잭션에 저장해야함을 의미한다.

```go
type Block struct {
        Timestamp     int64
        Transactions  []*Transaction
        PrevBlockHash []byte
        Hash          []byte
        Nonce         int
}
```

**NewBlock**과 **NewGenesisBlock**도 수정하자.

```go
func NewBlock(transactions []*Transaction, prevBlockHash []byte) *Block {
        block := &Block{time.Now().Unix(), transactions, prevBlockHash, []byte{}, 0}
        ...
}

func NewGenesisBlock(coinbase *Transaction) *Block {
        return NewBlock([]*Transaction{coinbase}, []byte{})
}
```

다음으로 수정할 것은 새로운 블록체인을 만드는 함수이다.

```go
func CreateBlockchain(address string) *Blockchain {
        ...
        err = db.Update(func(tx *bolt.Tx) error {
                cbtx := NewCoinbaseTX(address, genesisCoinbaseData)
                genesis := NewGenesisBlock(cbtx)
                b, err := tx.CreateBucket([]byte(blocksBucket))
                err = b.Put(genesis.Hash, genesis.Serialize())
                ...
        })
        ...
}
```

이제 함수는 제네시스 블록 채굴 보상을 받을 주소를 받는다.

# 작업 증명

작업 증명 알고리즘은 트랜잭션 저장소인 블록체인의 일관성과 신뢰성을 보장하기 위해 블록에 저장된 트랜잭션을 고려해야한다. 따라서 **ProofOfWork.prepareData** 메서드를 다음과 같이 수정해야한다.

```go
func (pow *ProofOfWork) prepareData(nonce int) []byte {
        data := bytes.Join(
                [][]byte{
                        pow.block.PrevBlockHash,
                        pow.block.HashTransactions(), // 수정된 부분
                        IntToHex(pow.block.Timestamp),
                        IntToHex(int64(targetBits)),
                        IntToHex(int64(nonce)),
                },
                []byte{},
        )

        return data
}
```

이제 **pow.block.Data** 대신 **pow.block.HashTransactions()**를 사용한다.

```go
func (b *Block) HashTransactions() []byte {
        var txHashes [][]byte
        var txHash [32]byte

        for _, tx := range b.Transactions {
                txHashes = append(txHashes, tx.ID)
        }
        txHash = sha256.Sum256(bytes.Join(txHashes, []byte{}))
        return txHash[:]
}
```

우리는 고유한 데이터의 표현을 제공하는 메커니즘으로 해싱을 사용하고 있다. 우리는 블록의 모든 트랜잭션을 고유한 단일 해시로 만들어 식별하고싶다. 이를 위해 각 트랜잭션의 해시들을 연결하고 연결된 문자열의 해시값을 가져와 사용할 것이다.

> 비트코인은 좀 더 정교한 기술한다. 블록의 모든 트랜잭션을 [머클 트리](https://en.wikipedia.org/wiki/Merkle_tree)로 표현하며 작업 증명 시스템에선 이 트리의 루트 해시를 사용한다. 이 방식을 사용하면 모든 트랜잭션을 다운로드 받지 않아도 루트 해시만 가지고도 블록에 특정 트랜잭션이 포함되어 있는지 빠르게 확인할 수 있다.

여기까지 잘 동작하는지 확인해보자.

```
$ blockchain_go createblockchain -address Ivan
00000093450837f8b52b78c25f8163bb6137caf43ff4d9a01d1b731fa8ddcc8a

Done!
```

훌륭하다! 우리는 첫 채굴 보상을 얻었다. 그런데 잔고는 어떻게 확인할 수 있을까?

# 미사용 트랜잭션 출력

우리는 모든 미사용 트랜잭션 출력 (UTXO)을 찾아야한다. *미사용*이란 그 어떤 입력에서도 참조되지 않은 출력을 의미한다. 위 다이어그램에서 미사용 트랜잭션은 다음과 같다.

1. tx0, output 1;
2. tx1, output 0;
3. tx3, output 0;
4. tx4, output 0.

물론, 잔고를 확인할 때 모든 트랜잭션 출력이 필요한건 아니며 우리가 가지고 있는 키로 잠금을 해제할 수 있는 출력만 필요하다 (현재는 키를 구현하지 않았으므로 사용자 정의 주소를 대신 사용할 것이다). 우선 입력과 출력에 잠금-해제 메서드를 정의하자.

```go
func (in *TXInput) CanUnlockOutputWith(unlockingData string) bool {
	    return in.ScriptSig == unlockingData
}

func (out *TXOutput) CanBeUnlockedWith(unlockingData string) bool {
    	return out.ScriptPubKey == unlockingData
}
```

단순히 스크립트 필드와 **unlockingData**을 비교하고 있다. 이 부분은 나중에 개인키 기반의 주소를 구현한 다음 개선할 것이다.

다음 단계는 미사용 출력을 포함하는 트랜잭션을 찾는 작업인데 조금 까다롭다.

```go
func (bc *Blockchain) FindUnspentTransactions(address string) []Transaction {
    var unspentTXs []Transaction
    spentTXOs := make(map[string][]int)
    bci := bc.Iterator()

    for {
        block := bci.Next()
        for _, tx := range block.Transactions {
            txID := hex.EncodeToString(tx.ID)

        Outputs:
            for outIdx, out := range tx.Vout {
                // 출력 사용 여부 검사
                if spentTXOs[txID] != nil {
                    for _, spentOut := range spentTXOs[txID] {
                        if spentOut == outIdx {
                            continue Outputs
                        }
                    }
                }
                if out.CanBeUnlockedWith(address) {
                    unspentTXs = append(unspentTXs, *tx)
                }
            }

            if tx.IsCoinbase() == false {
                for _, in := range tx.Vin {
                    if in.CanUnlockOutputWith(address) {
                        inTxID := hex.EncodeToString(in.Txid)
                        spentTXOs[inTxID] = append(spentTXOs[inTxID], in.Vout)
                    }
                }
            }
        }
    }
}
```

트랜잭션은 블록에 저장되기 때문에 블록체인의 모든 블록을 검사해야한다.

출력부터 시작하자.

```go
if out.CanBeUnlockedWith(address) {
    	unspentTXs = append(unspentTXs, tx)
}
```

어떤 출력이 우리가 찾고 있는 미사용 트랜잭션의 출력과 동일한 주소로 잠궈져있다면 이 출력이 바로 우리가 원하는 출력이다. 그러나 출력을 가져오기 전에 먼저 이 출력이 입력에서 이미 참조되었는지 확인할 필요가 있다.

```go
if spentTXOs[txID] != nil {
        for _, spentOut := range spentTXOs[txID] {
                if spentOut == outIdx {
                        continue Outputs
                }
        }
}
```

입력에서 이미 참조된 출력들은 무시한다 (이 출력들의 값들은 다른 출력으로 이동했기 때문에 카운트 할 수 없다). 출력 검사가 끝나면 주어진 주소로 잠긴 출력을 해제할 수 있는 모든 입력들을 가져온다 (코인베이스 트랜잭션은 출력을 해제하지 않기 때문에 제외한다).

```go
if tx.IsCoinbase() == false {
        for _, in := range tx.Vin {
                if in.CanUnlockOutputWith(address) {
                        inTxID := hex.EncodeToString(in.Txid)
                        spentTXOs[inTxID] = append(spentTXOs[inTxID], in.Vout)
                }
        }
}
```

위 함수는 미사용 출력을 포함하고 있는 트랜잭션의 리스트를 반환한다. 잔고 계산을 위해선 트랜잭션 리스트에서 출력들만 반환하는 함수가 하나 더 필요하다.

```go
func (bc *Blockchain) FindUTXO(address string) []TXOutput {
        var UTXOs []TXOutput
        unspentTransactions := bc.FindUnspentTransactions(address)
        for _, tx := range unspentTransactions {
                for _, out := range tx.Vout {
                        if out.CanBeUnlockedWith(address) {
                                UTXOs = append(UTXOs, out)
                        }
                }
        }
        return UTXOs
}
```

다 됐다! 이제 **getbalance** 커맨드를 구현할 수 있다.

```go
func (cli *CLI) getBalance(address string) {
        bc := NewBlockchain(address)
        defer bc.db.Close()

        balance := 0
        UTXOs := bc.FindUTXO(address)

        for _, out := range UTXOs {
                balance += out.Value
        }
        fmt.Printf("Balance of '%s': %d\n", address, balance)
}
```

계좌 잔고는 계좌 주소로 잠긴 모든 미사용 트랜잭션 출력값의 합이다.

제네시스 블록 채굴후 잔고를 확인해보자.

```
$ blockchain_go getbalance -address Ivan
Balance of 'Ivan': 10
```

우리의 첫 자산이다!

# 코인 전송

이제 다른 사람에게 코인을 전송해보자. 이를 위해선 새로운 트랜잭션을 생성하여 블록에 넣고 블록을 채굴해야한다. 지금까지 우리는 특수한 타입의 트랜잭션인 코인베이스 트랜잭션만 구현했으니 이제 일반 트랜잭션을 구현해보자.

```go
func NewUTXOTransaction(from, to string, amount int, bc *Blockchain) *Transaction {
        var inputs []TXInput
        var outputs []TXOutput

        acc, validOutputs := bc.FindSpendableOutputs(from, amount)

        if acc < amount {
                log.Panic("ERRPR: NOt enough funds")
        }

        // 입력 리스트 생성
        for txid, outs := range validOutputs {
                txID, err := hex.DecodeString(txid)

                for _, out := outs {
                        input := TXInput{txID, out, from}
                        inputs := append(inputs, input)
                }
        }

        // 출력 리스트 생성
        outputs = append(outputs, TXOutput{amount, to})
        if acc > amount {
                outputs = append(outputs, TXOutput{acc - amount, from})
        }

        tx := Transaction{nil, inputs, outputs}
        tx.SetID()
        return &tx
}
```

새로운 출력을 생성하기 전에, 우선 모든 미사용 출력을 찾아 충분한 잔고를 가지고 있는지 확인해야한다. 이것이 **FindSpendableOutputs** 메서드가 하는 일이다. 확인이 끝나면 찾아낸 각각의 출력에 대해 이를 참조하는 입력들이 생성된다. 그 후엔 다음 두 개의 출력을 생성한다.

1. 수신자 주소로 잠근 출력. 실제로 다른 주소로 코인을 전송하는 출력이다.
2. 발신자 주소로 잠근 출력. 이는 잔액인데, 미사용 출력들의 보유량이 새로운 트랜잭션에서 필요한 값보다 큰 경우에만 만들어진다. 출력은 **나눠질 수 없음**을 기억하라.

**FindSpendableOutputs** 메서드는 이전에 정의한 **FindUspentTransactions**을 기반으로한다.

```go
func (bc *Blockchain) FindSpendableOutputs(address string, amount int) (int, map[string][]int) {
        unspentOutputs := make(map[string][]int)
        unspentTXs := bc.FindUnspentTransactions(address)
        accumulated := 0

Work:
        for _, tx := range unspentTXs {
                txID := hex.EncodeToString(tx.ID)

                for outIdx, out := range tx.Vout {
                        if out.CanBeUnlockedWith(address) && accumulated < amount {
                                accumulated += out.Value
                                unspentOutputs[txID] = append(unspentOutputs[txID], outIdx)
                        }

                        if accumulated >= amount {
                                break Work
                        }
                }
        }

        return accumulated, unspentOutputs
}
```

이 메서드는 모든 미사용 트랜잭션을 순회하면서 값을 누적한다. 누적값이 전송하려는 양보다 크거나 같으면 순회를 끝내고 누적된 값과 트랜잭션 아이디로 그룹핑된 출력을 반환한다. 필요한 양보다 많은 양을 사용할 필요는 없다.

이제 **Blockchain.MineBlock** 메서드를 수정할 수 있다.

```go
func (bc *Blockchain) MineBlock(transactions []*Transaction) {
        ...
        newBlock := NewBlock(transactions, lastHash)
        ...
}
```

마지막으로 **send** 커맨드를 구현해보자.

```go
func (cli *CLI) send(from, to string, amount int) {
        bc := NewBlockchain(from)
        defer bc.db.Close()

        tx := NewUTXOTransaction(from, to, amount, bc)
        bc.MineBlock([]*Transaction{tx})
        fmt.Println("Success!")
}
```

코인을 전송한다는건 트랜잭션을 만들고 블록 채굴을 통해 이를 블록체인에 추가한다는 것을 의미한다. 그러나 비트코인은 우리가 구현한 것처럼 이 작업을 즉시 수행하지는 않는다. 대신 새로운 트랜잭션들을 메모리풀에 넣고 채굴자가 채굴할 준비가 되면 메모리풀에서 모든 트랜잭션을 가져와 후보 블록을 생성한다. 트랜잭션은 이를 포함하고 있는 블록이 채굴되고 블록체인에 추가될 때에만 컨펌을 받게 된다.

코인 전송 기능이 잘 동작하는지 확인해보자.

```
$ blockchain_go send -from Ivan -to Pedro -amount 6
00000001b56d60f86f72ab2a59fadb197d767b97d4873732be505e0a65cc1e37

Success!

$ blockchain_go getbalance -address Ivan
Balance of 'Ivan': 4

$ blockchain_go getbalance -address Pedro
Balance of 'Pedro': 6
```

잘 동작한다! 이제 더 많은 트랜잭션을 생성하고 여러 출력에서 전송이 잘 되는지 확인해보자.

```
$ blockchain_go send -from Pedro -to Helen -amount 2
00000099938725eb2c7730844b3cd40209d46bce2c2af9d87c2b7611fe9d5bdf

Success!

$ blockchain_go send -from Ivan -to Helen -amount 2
000000a2edf94334b1d94f98d22d7e4c973261660397dc7340464f7959a7a9aa

Success!
```

이제 Helen의 코인은 두 출력에 의해 잠궈졌다. 하나는 Pedro, 또 하나는 Ivan이 생성한 트랜잭션이다. Helen의 코인을 다른 사람에게 전송해보자.

```
$ blockchain_go send -from Helen -to Rachel -amount 3
000000c58136cffa669e767b8f881d16e2ede3974d71df43058baaf8c069f1a0

Success!

$ blockchain_go getbalance -address Ivan
Balance of 'Ivan': 2

$ blockchain_go getbalance -address Pedro
Balance of 'Pedro': 4

$ blockchain_go getbalance -address Helen
Balance of 'Helen': 1

$ blockchain_go getbalance -address Rachel
Balance of 'Rachel': 3
```

잘 동작한다! 전송 실패 테스트도 해보자.

```
$ blockchain_go send -from Pedro -to Ivan -amount 5
panic: ERROR: Not enough funds

$ blockchain_go getbalance -address Pedro
Balance of 'Pedro': 4

$ blockchain_go getbalance -address Ivan
Balance of 'Ivan': 2
```

# 결론

쉽지 않은 여정이었지만 우리는 이제 트랜잭션을 갖게되었다. 하지만 아직 비트코인과 같은 암호화 화폐들이 갖고있는 일부 중요한 핵심 기능들이 빠져있다.

1. 주소. 우리에겐 아직 실제 개인키를 기반으로 하는 주소가 없다.
2. 보상. 블록 채굴에 대한 보상을 못받고 있다.
3. UTXO 집합. 지금은 잔고 계산을 위해 모든 블랙체인을 스캔하고 있는데, 이는 블록이 많아질수록 매우 오래 걸릴수 있다. 또한 최근에 생성된 트랜잭션에 대한 검증 작업에도 아주 많은 시간이 소요될 수 있다. UTXO 집합은 이러한 문제를 해결하고 트랜잭션 관련 연산을 빠르게 만들어준다.
4. Mempool. Mempool은 트랜잭션이 블록에 포함되기 전까지 저장되는 장소이다. 우리가 구현한 블록체인에선 한 블록이 단 하나의 트랜잭션만 포함하는데, 이는 매우 비효율적이다.