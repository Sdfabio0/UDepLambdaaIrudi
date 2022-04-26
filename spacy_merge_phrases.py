import spacy
import nltk


nlp = spacy.load("en_core_web_sm")

def merge_phrases(doc):
    with doc.retokenize() as retokenizer:
        for np in list(doc.noun_chunks):
            attrs = {
                "tag": np.root.tag_,
                "lemma": np.root.lemma_,
                "ent_type": np.root.ent_type_,
            }
            retokenizer.merge(np, attrs=attrs)
    return doc

def merge_punct(doc):
    spans = []
    for word in doc[:-1]:
        if word.is_punct or not word.nbor(1).is_punct:
            continue
        start = word.i
        end = word.i + 1
        while end < len(doc) and doc[end].is_punct:
            end += 1
        span = doc[start:end]
        spans.append((span, word.tag_, word.lemma_, word.ent_type_))
    with doc.retokenize() as retokenizer:
        for span, tag, lemma, ent_type in spans:
            attrs = {"tag": tag, "lemma": lemma, "ent_type": ent_type}
            retokenizer.merge(span, attrs=attrs)
    return doc

def generate_noun_phrase_sent(phrase):
    doc = nlp(phrase)
    # Merge noun phrases into one token.
    doc = merge_phrases(doc)
    # Attach punctuation to tokens
    #doc = merge_punct(doc)
    sent = []

    for token in doc:
        print(token.text, token.pos_, token.dep_, token.head.text)
        words = nltk.word_tokenize(token.text)
        if len(words) >= 2:
            merge_word = '_'.join(words)
        else:
            merge_word = words[0]
        sent.append(merge_word)

    sent = ' '.join(sent)
    puncts = [',','.',':',';',r"'"]
    idx=0

    while idx<len(sent):
        s = sent[idx]
        if s in puncts:
            sent  = sent[:idx-1] + sent[idx:]
        idx+=1

    with open('input-english2.txt','w') as f:
        f.write(r'{"sentence":"'+sent+r'"}')
        f.write('\n')
    return
