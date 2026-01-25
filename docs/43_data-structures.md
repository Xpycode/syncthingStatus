<!--
TRIGGERS: data structure, array, dictionary, tree, graph, algorithm, collection
PHASE: any
LOAD: on-request
-->

# Data Structures

A reference for the containers and organizational patterns used to store and manipulate data.

## Linear Structures

### Array / List
An ordered collection of elements accessible by index (position).

```
Index:    0      1      2      3      4
        ┌──────┬──────┬──────┬──────┬──────┐
        │ "a"  │ "b"  │ "c"  │ "d"  │ "e"  │
        └──────┴──────┴──────┴──────┴──────┘

Access: array[2] → "c"
```

Properties:
- Ordered (maintains insertion order)
- Indexed (fast access by position)
- May be fixed-size or dynamic

Operations:
- Access by index: O(1) – instant
- Search: O(n) – must check each element
- Insert/delete at end: O(1)
- Insert/delete at beginning/middle: O(n) – must shift elements

### Linked List
Elements (nodes) connected by pointers. Each node points to the next.

```
┌───┬───┐    ┌───┬───┐    ┌───┬───┐
│ A │ ●─┼───→│ B │ ●─┼───→│ C │ ∅ │
└───┴───┘    └───┴───┘    └───┴───┘
 data next    data next    data next (null)
```

Types:
- Singly linked: each node points to next
- Doubly linked: each node points to next AND previous
- Circular: last node points back to first

Properties:
- No index access (must traverse from start)
- Efficient insert/delete if you have a reference to the node
- Dynamic size

### Stack
Last-In-First-Out (LIFO). Like a stack of plates.

```
        ┌───────┐
Push →  │   C   │  ← Pop (most recent)
        ├───────┤
        │   B   │
        ├───────┤
        │   A   │  (oldest)
        └───────┘
```

Operations:
- Push: add to top
- Pop: remove from top
- Peek/Top: view top without removing

Use cases: undo history, function call stack, bracket matching, back button

### Queue
First-In-First-Out (FIFO). Like a line at a shop.

```
Enqueue →  ┌───┬───┬───┬───┐  → Dequeue
           │ D │ C │ B │ A │
           └───┴───┴───┴───┘
          back            front
```

Operations:
- Enqueue: add to back
- Dequeue: remove from front
- Peek/Front: view front without removing

Use cases: task scheduling, print queues, breadth-first search

### Deque (Double-Ended Queue)
Queue that allows insert/remove from both ends.

```
     ┌───┬───┬───┬───┐
←──  │ A │ B │ C │ D │  ──→
     └───┴───┴───┴───┘
  front              back
```

Pronounced "deck".

### Priority Queue
Queue where elements have priorities. Highest priority dequeues first regardless of insertion order.

```
Enqueue (priority 3) ──→  ┌─────────────────┐
Enqueue (priority 1) ──→  │ Sorted by       │  ──→ Dequeue (highest priority)
Enqueue (priority 5) ──→  │ priority        │
                          └─────────────────┘
```

Use cases: task scheduling, Dijkstra's algorithm, event simulation

## Associative Structures

### Dictionary / Map / Hash Map
Key-value pairs. Access values by unique keys.

```
┌─────────────┬─────────────┐
│    Key      │    Value    │
├─────────────┼─────────────┤
│ "name"      │ "Alice"     │
│ "age"       │ 30          │
│ "city"      │ "Berlin"    │
└─────────────┴─────────────┘

Access: dict["name"] → "Alice"
```

Properties:
- Keys must be unique
- Keys must be hashable (immutable)
- Unordered (in most implementations)
- O(1) average access by key

Also called: HashMap (Java), Dictionary (C#, Swift, Python), Object (JavaScript, sort of), Hash (Ruby)

### Set
Unordered collection of unique elements.

```
{ "apple", "banana", "cherry" }

Add "apple" again → still { "apple", "banana", "cherry" }
```

Operations:
- Add, remove, contains: O(1) average
- Union: combine two sets
- Intersection: elements in both sets
- Difference: elements in one but not other

Use cases: deduplication, membership testing, mathematical set operations

### Ordered Dictionary / Linked Hash Map
Dictionary that remembers insertion order.

### Multimap
Dictionary where each key can have multiple values.

### Multiset / Bag
Set that allows duplicates (counts occurrences).

## Tree Structures

### Tree (General)
Hierarchical structure with nodes connected by edges.

```
           ┌───┐
           │ A │         ← root
           └─┬─┘
        ┌────┴────┐
      ┌─┴─┐     ┌─┴─┐
      │ B │     │ C │    ← children of A
      └─┬─┘     └─┬─┘
     ┌──┴──┐     │
   ┌─┴─┐ ┌─┴─┐ ┌─┴─┐
   │ D │ │ E │ │ F │     ← leaves (no children)
   └───┘ └───┘ └───┘
```

Terminology:
- Root: top node (no parent)
- Parent/Child: connected nodes
- Leaf: node with no children
- Sibling: nodes with same parent
- Depth: distance from root
- Height: longest path to a leaf
- Subtree: a node and all its descendants

### Binary Tree
Each node has at most two children (left and right).

```
       ┌───┐
       │ 5 │
       └─┬─┘
    ┌────┴────┐
  ┌─┴─┐     ┌─┴─┐
  │ 3 │     │ 7 │
  └─┬─┘     └─┬─┘
 ┌──┴──┐   ┌──┴──┐
┌┴┐   ┌┴┐ ┌┴┐   ┌┴┐
│2│   │4│ │6│   │8│
└─┘   └─┘ └─┘   └─┘
```

### Binary Search Tree (BST)
Binary tree where left children < parent < right children.

Enables O(log n) search, insert, delete (when balanced).

### Balanced Trees
Trees that maintain balance for consistent performance.

Types:
- AVL Tree: strictly balanced (heights differ by at most 1)
- Red-Black Tree: loosely balanced (used in many language standard libraries)
- B-Tree: multi-way tree (used in databases and file systems)

### Heap
Complete binary tree where parent is always greater (max-heap) or smaller (min-heap) than children.

```
Max-heap:
       ┌───┐
       │ 9 │     ← maximum always at root
       └─┬─┘
    ┌────┴────┐
  ┌─┴─┐     ┌─┴─┐
  │ 7 │     │ 6 │
  └───┘     └───┘
```

Use cases: priority queues, heap sort

### Trie (Prefix Tree)
Tree for storing strings where each node represents a character.

```
            root
         ┌───┴───┐
         t       a
         │       │
         e       p
        ┌┴┐      │
        a n      p
        │        │
       (tea)    (app)
```

Use cases: autocomplete, spell check, IP routing

## Graph Structures

### Graph
Nodes (vertices) connected by edges. More general than trees (can have cycles, multiple connections).

```
Undirected:          Directed:
    A───B            A───→B
    │\ /│            │    ↓
    │ X │            ↓    C
    │/ \│            D←───┘
    C───D
```

Types:
- Directed: edges have direction (A→B ≠ B→A)
- Undirected: edges go both ways
- Weighted: edges have values (distances, costs)
- Unweighted: all edges equal

### Adjacency List
Graph representation: each node stores list of its neighbors.

```
A: [B, C]
B: [A, C, D]
C: [A, B]
D: [B]
```

Memory efficient for sparse graphs.

### Adjacency Matrix
Graph representation: 2D array where matrix[i][j] = 1 if edge exists.

```
    A  B  C  D
A [ 0  1  1  0 ]
B [ 1  0  1  1 ]
C [ 1  1  0  0 ]
D [ 0  1  0  0 ]
```

Fast edge lookup, but uses more memory.

## Specialized Structures

### Tuple
Fixed-size, ordered collection of elements (possibly different types). Immutable.

```
(42, "hello", true)    # can't change after creation
```

### Record / Struct
Named fields of possibly different types.

```
Person {
    name: "Alice"
    age: 30
    active: true
}
```

### Enum
A type with a fixed set of possible values.

```
enum Direction { North, South, East, West }
enum Status { Pending, Approved, Rejected }
```

### Optional / Nullable
A value that might be present or absent.

```
Optional<String>:  "hello" or nil/null/none
```

### Result
Represents success with a value OR failure with an error.

```
Result<Int, Error>:  .success(42) or .failure(someError)
```

### Buffer / Ring Buffer
Fixed-size array that wraps around. Old data overwritten when full.

```
     write position
          ↓
┌───┬───┬───┬───┬───┐
│ D │ E │   │ B │ C │  ← reading starts at B
└───┴───┴───┴───┴───┘
              ↑
        read position
```

Use cases: streaming data, logging, audio buffers

## Complexity Quick Reference

| Structure | Access | Search | Insert | Delete | Notes |
|-----------|--------|--------|--------|--------|-------|
| Array | O(1) | O(n) | O(n) | O(n) | O(1) at end |
| Linked List | O(n) | O(n) | O(1) | O(1) | If you have node reference |
| Stack | O(n) | O(n) | O(1) | O(1) | Top only |
| Queue | O(n) | O(n) | O(1) | O(1) | Front/back only |
| Hash Map | – | O(1)* | O(1)* | O(1)* | *Average case |
| Set | – | O(1)* | O(1)* | O(1)* | *Average case |
| BST | – | O(log n)* | O(log n)* | O(log n)* | *When balanced |
| Heap | – | O(n) | O(log n) | O(log n) | O(1) to get min/max |

## Related Terms

- **Mutable**: can be changed after creation
- **Immutable**: cannot be changed after creation
- **Iterable**: can be looped over
- **Hashable**: can be used as a dictionary key (needs hash function)
- **Comparable**: can be sorted (needs comparison operators)
- **Generic**: works with any type (Array<T>, Dictionary<K, V>)
- **Abstract Data Type (ADT)**: the concept (e.g., "stack") vs implementation
- **Data structure**: the concrete implementation
