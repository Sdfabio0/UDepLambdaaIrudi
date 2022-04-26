from fastapi import FastAPI
import os
import json
from zipfile import ZipFile
from fastapi.responses import StreamingResponse, FileResponse
import networkx as nx
import matplotlib.pyplot as plt
import re
import nltk
import spacy_merge_phrases
nltk.download('punkt')

path = '/home/fabrice/Documents/UDepLambda'

def function_predicate_parse(dep,sent):
    words = nltk.word_tokenize(sent)
    idxs_semi = [(m.start(0), m.end(0)) for m in re.finditer(':', dep)]
    idxs_words = re.findall('\d+',dep)
    idx1 = idxs_semi[0]
    idx2 = idxs_semi[1]
    name = words[int(idxs_words[-2])]
    target = words[int(idxs_words[-1])]
    if dep[int(idx1[0]+1)] == 's':
        func = 's'
        color_name = 'yellow'
        shape_name = 's'
    elif dep[int(idx1[0]+1)] == 'e':
        func = 'e'
        color_name = 'red'
        name = 'e.'+ name
        shape_name = 'o'
    if dep[int(idx2[0]+1)] == 'x':
        target = 'x.'+target

    dic = {'func':func,'name':name,'target':target,'color_name':color_name,'color_target':'green','shape_name':shape_name,'shape_target':'o'}
    return dic

def add_node_graph(G,dic):
    name = dic['name']
    target = dic['target']
    func = dic['func']
    edge_label = ''
    if name not in list(G.nodes):
        G.add_nodes_from([(name, {"color": dic['color_name']})])
        colors[name] = dic['color_name']
        shapes[name] = dic['shape_name']
    if target not in list(G.nodes):
        G.add_nodes_from([(target, {"color": dic['color_target']})])
        colors[target] = dic['color_target']
        shapes[target] = dic['shape_target']
    if func == 'e':
        edge_label = name + '.arg'
    G.add_edges_from([(name,target)],edge_labels=edge_label,font_color='red')
    return G

colors = {}
shapes = {}
app = FastAPI()

@app.get("/")
def root():
    with open('input-english.txt','r') as f:
       line  = f.readline()
    dic_sent = json.loads(line)
    sentence = dic_sent['sentence']
    sent = spacy_merge_phrases.generate_noun_phrase_sent(sentence)
    print(sent)
    with open('input-english2.txt','w') as f:
        f.write(r'{"sentence":"'+sent+r'"}')
        f.write('\n')
    sent_file = 'input-english2.txt'
    output = 'output.json'
    #preprocessing of the sentence into a JSON file
    command = 'cat '+ sent_file +' | sh run-english.sh > '+ output
    os.system(command)
    # importing the dictionary
    # Opening JSON file
    with open('output.json') as json_file:
        dic_work = json.load(json_file)   
    return dic_work

@app.post("/logic_graph")
def logic_graph_processing(sent):
    true = True
    G = nx.DiGraph()
    dic_sent = {"sentence":sent}	
    sent_file = 'input-test-en.txt'
    with open(sent_file, 'w') as f:
    	f.write(json.dumps(dic_sent))	
    output = 'output.json'
    #preprocessing of the sentence into a JSON file
    command = 'cat '+ sent_file +' | sh run-english.sh > '+ output
    os.system(command)

    # importing the dictionary
    # Opening JSON file
    with open('output.json') as json_file:
        dic_work = json.load(json_file)
    for dep in dic_work['dependency_lambda']:
        for el in dep:
            nums = len(re.findall(':',el))
            dic_props = function_predicate_parse(el,dic_work['sentence'])
            G = add_node_graph(G,dic_props)

    pos = nx.planar_layout(G,scale=2)
    font = 20/((len(list(G.nodes)))**(1/4))
    size_node = 2200/((len(list(G.nodes)))**(1/4))
    fig = plt.figure()
    nx.draw(G, pos=pos, ax=fig.add_subplot(111), node_color = list(colors.values()),node_size = size_node,
    with_labels = True, font_size=font,node_shape ='o',arrows=True,edgecolors='black',width=2)  #   networkx draw()
    nx.draw_networkx_edge_labels(G,pos,edge_labels=nx.get_edge_attributes(G,'edge_labels'), font_size=font, ax=fig.add_subplot(111))
    fig.savefig("Graph.png", format="PNG")  
    file_path = os.path.join(path,'Graph.png')
    return FileResponse(file_path,media_type="image/png",filename="Graph.png")
