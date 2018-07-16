# The Anagramer

Solution to the Fluentcity Coding Challenge, [try it out](http://107.150.29.125:5000/)!

## The Challenge

Write a function that takes an english word as an input and checks if the word exists in a dictionary of words (provided via the `dictionary.txt` file). If the word exists in the dictionary then return all valid anagrams of that word sorted alphabetically by its second letter. If the word does not exist in the dictionary then return `None`.

## The Solution

### Intuition

To begin lets define **anagram** to be: *a word that permutes itself*, where we consider a *"word"* in this context to mean any valid English word. Essentially anagrams are words that use the same characters in different arrangements.

We can normalize the problem by imagining a one-to-many relationship between words and their list of anagrams. Naturally for this model we will require some sort of foreign key.

If we can craft a function that returns the same value given any permutation of a word, we can generate our foreign keys on the fly and essentially form a hash-map. The simplest form of such a function is illustrated below:

```python

''' Returns letters of word sorted alphabetically '''
def normalize(word):
    # Implement a namespace for foreign keys
    return "fk:" + "".join(sorted(word))

# normalize('hello') -> 'ehllo'
# normalize('lehol') -> 'ehllo'

```

### Algorithm

I broke the sorting algorithm down into two main steps:

* Iterate over `dictionary.txt`
    - Map words to hash
* Iterate over the English dictionary
    - Group words of the same hash

This allows us to search for anagrams by just computing the hash of the queried word and looking up what group of anagrams that value maps to.

```python

''' Search for list of anagrams '''
def search(word):
    word_hash = normalize(word)
    try:
        return cache.get(word_hash)
    except:
        return None

```

#### Potential Issues

* How do we prevent iterating over english words that do not map to any word in `dictionary.txt`?

* How can we optimize updates?

* How can we mitigate bottlenecks like our hash function?

### Storage Models

Given that the primary usage of the application is to query for available anagrams, it's only going to require **read operations in production**. I decided to use Redis for persistance, the benefits for this application:

* In-memory cache (no reading to filesystem :relaxed:)
* List containers are implemented as Linked List

#### How do we prevent iterating over english words that do not map to any word in `dictionary.txt`?

To prevent this from occurring, before the first loop of our algorithm we create a lookup table (e.g python `dict`). For every hash generated from `dictionary.txt` we register it to our lookup table. This will let us know which hash's actually require an anagram mapping.

```python

''' Map words to list of anagrams '''
def sort():
    should_cache = {}
    
    for word in parse('dictionary.txt'):
        word_hash = normalize(word)
        cache.set(word, word_hash)
        # Update lookup table
        should_cache.update({ word_hash: True })
    
    # Treat each word as a potential anagram
    for anagram in parse('en-us.dict'):
        word_hash = normalize(anagram)
        # Check if we should cache this hash
        if word_hash in should_cache:
            # Append anagram to linked list
            cache.lpush(word_hash, anagram)
        else:
            pass
    #...
```

#### How can we optimize updates?

The next time we run this application, it should not have to re-map anagrams. To mitigate this we extend the functionality of our lookup table `should_cache` to also store words already cached. We can nest this data within the hash values already stored and store these new hierarchical collections also in a python `dict`. The benefit over a python `list` here is that we get `O(1)` read complexity in `dict` versus `O(n)` read (searching) complexity of `list`; it is a *lookup* table after all :wink:.

```python

''' Map words to list of anagrams '''
def sort():
    should_cache = {}
    
    for word in parse('dictionary.txt'):
        word_hash = normalize(word)
        cache.set(word, word_hash)
        # Update lookup table
        should_cache.update({ word_hash: dict() })
    
    # Treat each word as a potential anagram
    for anagram in parse('en-us.dict'):
        word_hash = normalize(anagram)
        # Check if we should cache this hash
        if word_hash in should_cache:
            # Check if this anagram was not cached
            if anagram not in should_cache[word_hash]:
                # Append anagram to linked list
                cache.lpush(word_hash, anagram)
        else:
            pass
    #...
```

We can further improve this by `pickling` the lookup table and persisting it directly into storage, **to avoid losing the history of what was cached**.

#### How can we mitigate bottlenecks like our hash function?

Pythons `sorted` [runs optimistically](https://en.wikipedia.org/wiki/Timsort) in `O(n log n)` time, this can become quite expensive given the size of our dataset.

An exotic, yet efficient solution, is to use prime numbers. [I unintentionally derived this solution a while back, feel free to read in detail how this process works](https://github.com/EzraSingh/permutation-algorithm/blob/master/permutation-algorithm.pdf).
Essentially we associate for every letter a prime number. Given any word we can map it's letters to a sequence of prime numbers. Multiplying out this sequence will give you a number invariant to the arrangement of the original set.

Thanks to the associative property of multiplication and the irreducibility of primes we have a function that can identify permutations in `O(n)`! [If we implemented this function recursively we could further improve its performance with memoization](https://github.com/EzraSingh/anagramer-server/blob/3c0c0a50195300762c8ea13b3794dace3511edb6/src/anagramer/utils.py#L19).
