# Compiles protos and creates source code.
compile_protos:
	protoc -I=protos --java_out=src protos/transformation-rules.proto

# Full commands of a language
create_data_%:
	make create_webquestions_$*
	make entity_annotate_webquestions_$*

create_tagging_data_%:
	make entity_dismabiguated_to_plain_forest_$*
	make plain_forest_to_conll_$* 

# At this point run the pos tagger and save its output

create_parsing_data_%:
	make process_postagger_$*
	make tagged_forest_to_conll_$*

# At this point run the dependency parser

create_deplambda_data_%:
	make merge_parsed_conll_with_forest_$*
	make deplambda_forest_$*

# Run BoW experiments
run_bow_experiments_%:
	#make extract_gold_graphs_bow_dev_$*
	make extract_gold_graphs_bow_$*
	make bow_supervised_without_merge_without_expand_$*

# Run dependency experiments
run_dependency_experiments_%:
	#make extract_gold_graphs_dependency_dev_$*
	make extract_gold_graphs_dependency_$*
	make dependency_with_merge_without_expand_$*
	make test_dependency_with_merge_without_expand_$*
	make dependency_without_merge_without_expand_$*

# Run deplambda experiments
run_deplambda_experiments_%:
	#make extract_gold_graphs_deplambda_dev_$*
	make extract_gold_graphs_deplambda_$*
	make deplambda_with_merge_with_expand.32_$*
	make deplambda_with_merge_with_expand.31_$*
	#make deplambda_with_merge_with_expand.32.stem_$*
	#make test_deplambda_with_merge_with_expand_$*
	#make deplambda_with_merge_without_expand_$*
	#make deplambda_without_merge_with_expand_$*
	#make deplambda_without_merge_without_expand_$*

run_deplambda_hyperexpand_%:
	make extract_gold_graphs_deplambda_hyperexpand_$*
	make deplambda_with_hyperexpand.32_$*
	#make deplambda_with_hyperexpand.31_$*

run_dependency_hyperexpand_%:
	make extract_gold_graphs_dependency_hyperexpand_$*
	make dependency_with_hyperexpand.32_$*

# TODO: Just use the model in the best iteration for testing.
run_tests_%:
	make lang_run_tests_$*-1
	make lang_run_tests_$*-2
	make lang_run_tests_$*-3

lang_run_tests_%:
	$(eval LANG := $(shell echo $* | cut -d- -f1))
	$(eval RUN := $(shell echo $* | cut -d- -f2))
	make get_test_results_$(LANG)-bilty-bist
	mv ../working/test_bow_supervised_without_merge_without_expand_$(LANG)-bilty-bist \
		../working/test_bow_supervised_without_merge_without_expand_$(LANG)-bilty-bist.$(RUN) 
	mv ../working/test_deplambda_with_hyperexpand.32_$(LANG)-bilty-bist \
		../working/test_deplambda_with_hyperexpand.32_$(LANG)-bilty-bist.$(RUN)
	mv ../working/test_dependency_with_hyperexpand.32_$(LANG)-bilty-bist \
		../working/test_dependency_with_hyperexpand.32_$(LANG)-bilty-bist.$(RUN)

get_test_results_%:
	make test_bow_supervised_without_merge_without_expand_$*
	make test_deplambda_with_hyperexpand.32_$*
	make test_dependency_with_hyperexpand.32_$*

# Data Preparation

# Parse WebQuestions
create_webquestions_en:
	cat data/webquestions/en/webquestions.examples.test.json \
		| python scripts/webquestions/convert_to_one_sentence_per_line.py \
		| python scripts/webquestions/add_gold_mid_using_gold_url.py data/freebase/mid_to_key.txt.gz \
		| java -cp lib/*: in.sivareddy.scripts.AddGoldRelationsToWebQuestionsData localhost data/freebase/schema/all_domains_schema.txt \
		> data/webquestions/en/webquestions.test.json
	cat data/webquestions/en/webquestions.examples.train.json \
		| python scripts/webquestions/convert_to_one_sentence_per_line.py \
		| python scripts/webquestions/extract_subset.py data/webquestions/webquestions_sentences.train.txt \
		| python scripts/webquestions/add_gold_mid_using_gold_url.py data/freebase/mid_to_key.txt.gz \
		| java -cp lib/*: in.sivareddy.scripts.AddGoldRelationsToWebQuestionsData localhost data/freebase/schema/all_domains_schema.txt \
		> data/webquestions/en/webquestions.train.json
	cat data/webquestions/en/webquestions.examples.train.json \
		| python scripts/webquestions/convert_to_one_sentence_per_line.py \
		| python scripts/webquestions/extract_subset.py data/webquestions/webquestions_sentences.dev.txt  \
		| python scripts/webquestions/add_gold_mid_using_gold_url.py data/freebase/mid_to_key.txt.gz \
		| java -cp lib/*: in.sivareddy.scripts.AddGoldRelationsToWebQuestionsData localhost data/freebase/schema/all_domains_schema.txt \
		> data/webquestions/en/webquestions.dev.json

create_webquestions_%:
	cat data/webquestions/en/webquestions.train.json \
		| python scripts/webquestions/merge_with_english.py \
		data/webquestions/$*/webquestions.examples.train.utterances_$* \
		data/webquestions/$*/webquestions.examples.train.utterances \
		> data/webquestions/$*/webquestions.train.json
	cat data/webquestions/en/webquestions.dev.json \
		| python scripts/webquestions/merge_with_english.py \
		data/webquestions/$*/webquestions.examples.train.utterances_$* \
		data/webquestions/$*/webquestions.examples.train.utterances \
		> data/webquestions/$*/webquestions.dev.json
	cat data/webquestions/en/webquestions.test.json \
		| python scripts/webquestions/merge_with_english.py \
		data/webquestions/$*/webquestions.examples.test.utterances_$* \
		data/webquestions/$*/webquestions.examples.test.utterances \
		> data/webquestions/$*/webquestions.test.json

entity_annotate_webquestions_%:
	cat data/webquestions/$*/webquestions.train.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit,pos,lemma \
		ssplit.newlineIsSentenceBreak always \
		languageCode $* \
		pos.model lib_data/utb-models/$*/pos-tagger/utb-caseless-$*-bidirectional-glove-distsim-lower.full.tagger \
		| java -cp bin:lib/* in.sivareddy.scripts.NounPhraseAnnotator $*_ud \
		> working/$*-webquestions.train.json
	cat data/webquestions/$*/webquestions.dev.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit,pos,lemma \
		ssplit.newlineIsSentenceBreak always \
		languageCode $* \
		pos.model lib_data/utb-models/$*/pos-tagger/utb-caseless-$*-bidirectional-glove-distsim-lower.full.tagger \
		| java -cp bin:lib/* in.sivareddy.scripts.NounPhraseAnnotator $*_ud \
		> working/$*-webquestions.dev.json
	cat data/webquestions/$*/webquestions.test.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit,pos,lemma \
		ssplit.newlineIsSentenceBreak always \
		languageCode $* \
		pos.model lib_data/utb-models/$*/pos-tagger/utb-caseless-$*-bidirectional-glove-distsim-lower.full.tagger \
		| java -cp bin:lib/* in.sivareddy.scripts.NounPhraseAnnotator $*_ud \
		> working/$*-webquestions.test.json

	# Entity Annotations
	cat working/$*-webquestions.dev.json \
		| java -cp bin:lib/* in.sivareddy.graphparser.cli.RankMatchedEntitiesCli \
		--useKG false \
		--apiKey AIzaSyDj-4Sr5TmDuEA8UVOd_89PqK87GABeoFg \
		--langCode $* \
		> working/$*-webquestions.dev.ranked.json
	cat working/$*-webquestions.test.json \
		| java -cp bin:lib/* in.sivareddy.graphparser.cli.RankMatchedEntitiesCli \
		--useKG false \
		--apiKey AIzaSyDj-4Sr5TmDuEA8UVOd_89PqK87GABeoFg \
		--langCode $* \
		> working/$*-webquestions.test.ranked.json
	cat working/$*-webquestions.train.json \
		| java -cp bin:lib/* in.sivareddy.graphparser.cli.RankMatchedEntitiesCli \
		--useKG false \
		--apiKey AIzaSyDj-4Sr5TmDuEA8UVOd_89PqK87GABeoFg \
		--langCode $* \
		> working/$*-webquestions.train.ranked.json
	# if successful, take backup. Freebase API may stop working anytime.
	#echo "Overwriting existing files: "
	cp -i working/$*-webquestions.train.ranked.json data/webquestions/$*/webquestions.train.ranked.json
	cp -i working/$*-webquestions.dev.ranked.json data/webquestions/$*/webquestions.dev.ranked.json
	cp -i working/$*-webquestions.test.ranked.json data/webquestions/$*/webquestions.test.ranked.json

evaluate_entity_annotation_upperbound_%:
	cat data/webquestions/$*/webquestions.dev.ranked.json \
		| python ../graph-parser/scripts/entity-annotation/get_entity_patterns.py

train_entity_annotator_%:
	mkdir -p data/entity-models
	java -cp bin:lib/* deplambda.cli.RunTrainEntityScorer \
		-nthreads 20 \
		-iterations 100 \
		-trainFile data/webquestions/$*/webquestions.train.ranked.json \
		-devFile data/webquestions/$*/webquestions.dev.ranked.json \
		-testFile data/webquestions/$*/webquestions.test.ranked.json \
		-saveToFile data/entity-models/$*-webquestions.ser

disambiguate_entities_%:
	cat data/webquestions/$*/webquestions.dev.ranked.json \
		| java -cp bin:lib/* deplambda.cli.RunEntityDisambiguator \
		-loadModelFromFile data/entity-models/$*-webquestions.ser \
		-endpoint localhost \
		-nthreads 20 \
		-nbestEntities 10 \
		-schema data/freebase/schema/all_domains_schema.txt \
		> data/webquestions/$*/webquestions.dev.disambiguated.json
	cat data/webquestions/$*/webquestions.train.ranked.json \
		| java -cp bin:lib/* deplambda.cli.RunEntityDisambiguator \
		-loadModelFromFile data/entity-models/$*-webquestions.ser \
		-endpoint localhost \
		-nthreads 20 \
		-nbestEntities 10 \
		-schema data/freebase/schema/all_domains_schema.txt \
		> data/webquestions/$*/webquestions.train.disambiguated.json
	cat data/webquestions/$*/webquestions.test.ranked.json \
		| java -cp bin:lib/* deplambda.cli.RunEntityDisambiguator \
		-loadModelFromFile data/entity-models/$*-webquestions.ser \
		-endpoint localhost \
		-nthreads 20 \
		-nbestEntities 10 \
		-schema data/freebase/schema/all_domains_schema.txt \
		> data/webquestions/$*/webquestions.test.disambiguated.json

entity_disambiguation_results_%:
	cat data/webquestions/$*/webquestions.dev.disambiguated.json \
	    | python ../graph-parser/scripts/entity-annotation/evaluate_entity_annotation.py 

entity_dismabiguated_to_plain_forest_en:
	cat data/webquestions/en/webquestions.dev.disambiguated.json \
		| java -cp bin:lib/* deplambda.util.CreateGraphParserForestFromEntityDisambiguatedSentences \
		preprocess.lowerCase true \
		annotators tokenize,ssplit,pos,lemma \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode en \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit,pos \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode en \
		posTagKey UD \
		pos.model lib_data/utb-models/en/pos-tagger/utb-caseless-en-bidirectional-glove-distsim-lower.full.tagger \
		> working/en-webquestions.dev.plain.forest.json 
	cat data/webquestions/en/webquestions.train.disambiguated.json \
		| java -cp bin:lib/* deplambda.util.CreateGraphParserForestFromEntityDisambiguatedSentences \
		preprocess.lowerCase true \
		annotators tokenize,ssplit,pos,lemma \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode en \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit,pos \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode en \
		posTagKey UD \
		pos.model lib_data/utb-models/en/pos-tagger/utb-caseless-en-bidirectional-glove-distsim-lower.full.tagger \
		> working/en-webquestions.train.plain.forest.json 
	cat data/webquestions/en/webquestions.test.disambiguated.json \
		| java -cp bin:lib/* deplambda.util.CreateGraphParserForestFromEntityDisambiguatedSentences \
		preprocess.lowerCase true \
		annotators tokenize,ssplit,pos,lemma \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode en \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit,pos \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode en \
		posTagKey UD \
		pos.model lib_data/utb-models/en/pos-tagger/utb-caseless-en-bidirectional-glove-distsim-lower.full.tagger \
		> working/en-webquestions.test.plain.forest.json 

entity_dismabiguated_to_plain_forest_%:
	cat data/webquestions/$*/webquestions.dev.disambiguated.json \
		| java -cp bin:lib/* deplambda.util.CreateGraphParserForestFromEntityDisambiguatedSentences \
		preprocess.lowerCase true \
		annotators tokenize,ssplit,pos \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode $* \
		posTagKey UD \
		pos.model lib_data/utb-models/$*/pos-tagger/utb-caseless-$*-bidirectional-glove-distsim-lower.full.tagger \
		| java -cp bin:lib/* deplambda.others.Stemmer $* 20 \
		> working/$*-webquestions.dev.plain.forest.json 
	cat data/webquestions/$*/webquestions.train.disambiguated.json \
		| java -cp bin:lib/* deplambda.util.CreateGraphParserForestFromEntityDisambiguatedSentences \
		preprocess.lowerCase true \
		annotators tokenize,ssplit,pos \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode $* \
		posTagKey UD \
		pos.model lib_data/utb-models/$*/pos-tagger/utb-caseless-$*-bidirectional-glove-distsim-lower.full.tagger \
		| java -cp bin:lib/* deplambda.others.Stemmer $* 20 \
		> working/$*-webquestions.train.plain.forest.json 
	cat data/webquestions/$*/webquestions.test.disambiguated.json \
		| java -cp bin:lib/* deplambda.util.CreateGraphParserForestFromEntityDisambiguatedSentences \
		preprocess.lowerCase true \
		annotators tokenize,ssplit,pos \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode $* \
		posTagKey UD \
		pos.model lib_data/utb-models/$*/pos-tagger/utb-caseless-$*-bidirectional-glove-distsim-lower.full.tagger \
		| java -cp bin:lib/* deplambda.others.Stemmer $* 20 \
		> working/$*-webquestions.test.plain.forest.json 

plain_forest_to_conll_%:
	cat working/$*-webquestions.dev.plain.forest.json \
		| java -cp bin:lib/* deplambda.others.ConvertGraphParserSentenceToConll \
		| sed -e "s/-lrb-/\(/g" \
		| sed -e "s/-rrb-/\)/g" \
		| sed -e "s/-RRB-/SYM/g" \
		| sed -e "s/-LRB-/SYM/g" \
		| python scripts/webquestions/make_conll_column_lowercase.py 1 \
		> working/$*-webquestions.dev.forest.conll 
	cp working/$*-webquestions.dev.forest.conll working/$*-stanford-webquestions.dev.forest.tagged.conll
	cat working/$*-webquestions.train.plain.forest.json \
		| java -cp bin:lib/* deplambda.others.ConvertGraphParserSentenceToConll \
		| sed -e "s/-lrb-/\(/g" \
		| sed -e "s/-rrb-/\)/g" \
		| sed -e "s/-RRB-/SYM/g" \
		| sed -e "s/-LRB-/SYM/g" \
		| python scripts/webquestions/make_conll_column_lowercase.py 1 \
		> working/$*-webquestions.train.forest.conll 
	cp working/$*-webquestions.train.forest.conll working/$*-stanford-webquestions.train.forest.tagged.conll
	cat working/$*-webquestions.test.plain.forest.json \
		| java -cp bin:lib/* deplambda.others.ConvertGraphParserSentenceToConll \
		| sed -e "s/-lrb-/\(/g" \
		| sed -e "s/-rrb-/\)/g" \
		| sed -e "s/-RRB-/SYM/g" \
		| sed -e "s/-LRB-/SYM/g" \
		| python scripts/webquestions/make_conll_column_lowercase.py 1 \
		> working/$*-webquestions.test.forest.conll 
	cp working/$*-webquestions.test.forest.conll working/$*-stanford-webquestions.test.forest.tagged.conll

process_postagger_%:
	$(eval LANG := $(shell echo $* | cut -d- -f1))
	python scripts/webquestions/copy_column_from_to.py 3:3,3:4 \
		working/$*-webquestions.dev.forest.tagged.conll \
		working/$(LANG)-webquestions.dev.forest.conll \
		| sed -e 's/_\t_\t_\t_$$/0\troot\t_\t_/g' \
		> working/$*-webquestions.dev.forest.tmp.conll
	java -cp bin:lib/* deplambda.others.MergeConllAndGraphParserFormats \
		working/$*-webquestions.dev.forest.tmp.conll \
		working/$(LANG)-webquestions.dev.plain.forest.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		preprocess.addDateEntities true \
		preprocess.mergeEntityWords true \
		annotators tokenize,ssplit \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode $* \
		posTagKey UD \
		postprocess.correctPosTags true \
		> working/$*-webquestions.dev.forest.json
	rm working/$*-webquestions.dev.forest.tmp.conll

	python scripts/webquestions/copy_column_from_to.py 3:3,3:4 \
		working/$*-webquestions.train.forest.tagged.conll \
		working/$(LANG)-webquestions.train.forest.conll \
		| sed -e 's/_\t_\t_\t_$$/0\troot\t_\t_/g' \
		> working/$*-webquestions.train.forest.tmp.conll
	java -cp bin:lib/* deplambda.others.MergeConllAndGraphParserFormats \
		working/$*-webquestions.train.forest.tmp.conll \
		working/$(LANG)-webquestions.train.plain.forest.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		preprocess.addDateEntities true \
		preprocess.mergeEntityWords true \
		annotators tokenize,ssplit \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode $* \
		posTagKey UD \
		postprocess.correctPosTags true \
		> working/$*-webquestions.train.forest.json
	rm working/$*-webquestions.train.forest.tmp.conll

	python scripts/webquestions/copy_column_from_to.py 3:3,3:4 \
		working/$*-webquestions.test.forest.tagged.conll \
		working/$(LANG)-webquestions.test.forest.conll \
		| sed -e 's/_\t_\t_\t_$$/0\troot\t_\t_/g' \
		> working/$*-webquestions.test.forest.tmp.conll
	java -cp bin:lib/* deplambda.others.MergeConllAndGraphParserFormats \
		working/$*-webquestions.test.forest.tmp.conll \
		working/$(LANG)-webquestions.test.plain.forest.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		preprocess.addDateEntities true \
		preprocess.mergeEntityWords true \
		annotators tokenize,ssplit \
		tokenize.whitespace true \
		ssplit.eolonly true \
		languageCode $* \
		posTagKey UD \
		postprocess.correctPosTags true \
		> working/$*-webquestions.test.forest.json
	rm working/$*-webquestions.test.forest.tmp.conll

tagged_forest_to_conll_%:
	cat working/$*-webquestions.dev.forest.json \
		| java -cp bin:lib/* deplambda.others.ConvertGraphParserSentenceToConll \
		| sed -e "s/-lrb-/\(/g" \
		| sed -e "s/-rrb-/\)/g" \
		| sed -e "s/-RRB-/SYM/g" \
		| sed -e "s/-LRB-/SYM/g" \
		| python scripts/webquestions/make_conll_column_lowercase.py 1 \
		| python scripts/webquestions/copy_coarse_pos_to_fine_pos.py \
		> working/$*-webquestions.dev.forest.conll
	cat working/$*-webquestions.train.forest.json \
		| java -cp bin:lib/* deplambda.others.ConvertGraphParserSentenceToConll \
		| sed -e "s/-lrb-/\(/g" \
		| sed -e "s/-rrb-/\)/g" \
		| sed -e "s/-RRB-/SYM/g" \
		| sed -e "s/-LRB-/SYM/g" \
		| python scripts/webquestions/make_conll_column_lowercase.py 1 \
		| python scripts/webquestions/copy_coarse_pos_to_fine_pos.py \
		> working/$*-webquestions.train.forest.conll
	cat working/$*-webquestions.test.forest.json \
		| java -cp bin:lib/* deplambda.others.ConvertGraphParserSentenceToConll \
		| sed -e "s/-lrb-/\(/g" \
		| sed -e "s/-rrb-/\)/g" \
		| sed -e "s/-RRB-/SYM/g" \
		| sed -e "s/-LRB-/SYM/g" \
		| python scripts/webquestions/make_conll_column_lowercase.py 1 \
		| python scripts/webquestions/copy_coarse_pos_to_fine_pos.py \
		> working/$*-webquestions.test.forest.conll

forest_to_sentences_%:
	mkdir -p working/webq_multillingual_graphpaser_constrained_entity_annotations/sent/$*
	cat working/$*-webquestions.dev.forest.json \
		| java -cp bin:lib/* deplambda.others.PrintSentencesFromWords \
		> working/webq_multillingual_graphpaser_constrained_entity_annotations/sent/$*/webquestions.dev.sentences.txt
	cat working/$*-webquestions.train.forest.json \
		| java -cp bin:lib/* deplambda.others.PrintSentencesFromWords \
		> working/webq_multillingual_graphpaser_constrained_entity_annotations/sent/$*/webquestions.train.sentences.txt
	cat working/$*-webquestions.test.forest.json \
		| java -cp bin:lib/* deplambda.others.PrintSentencesFromWords \
		> working/webq_multillingual_graphpaser_constrained_entity_annotations/sent/$*/webquestions.test.sentences.txt

stanford_parse_conll_%:
	cat working/$*-webquestions.dev.forest.conll \
		| sed -e 's/_\t_\t_\t_$$/0\troot\t_\t_/g' \
		> working/$*-webquestions.dev.forest.conll.tmp
	java -cp .:lib/* edu.stanford.nlp.parser.nndep.DependencyParser \
		-model lib_data/ud-models-v1.3/$*/neural-parser/$*-glove50.lower.nndep.model.txt.gz \
		-testFile working/$*-webquestions.dev.forest.conll.tmp \
		-outFile working/$*-stanford-webquestions.dev.forest.parsed.conll
	rm working/$*-webquestions.dev.forest.conll.tmp
	cat working/$*-webquestions.train.forest.conll \
		| sed -e 's/_\t_\t_\t_$$/0\troot\t_\t_/g' \
		> working/$*-webquestions.train.forest.conll.tmp
	java -cp .:lib/* edu.stanford.nlp.parser.nndep.DependencyParser \
		-model lib_data/ud-models-v1.3/$*/neural-parser/$*-glove50.lower.nndep.model.txt.gz \
		-testFile working/$*-webquestions.train.forest.conll.tmp \
		-outFile working/$*-stanford-webquestions.train.forest.parsed.conll
	rm working/$*-webquestions.train.forest.conll.tmp
	cat working/$*-webquestions.test.forest.conll \
		| sed -e 's/_\t_\t_\t_$$/0\troot\t_\t_/g' \
		> working/$*-webquestions.test.forest.conll.tmp
	java -cp .:lib/* edu.stanford.nlp.parser.nndep.DependencyParser \
		-model lib_data/ud-models-v1.3/$*/neural-parser/$*-glove50.lower.nndep.model.txt.gz \
		-testFile working/$*-webquestions.test.forest.conll.tmp \
		-outFile working/$*-stanford-webquestions.test.forest.parsed.conll
	rm working/$*-webquestions.test.forest.conll.tmp

merge_parsed_conll_with_forest_%:
	$(eval LANG := $(shell echo $* | cut -d- -f1))
	$(eval TAGGER := $(shell echo $* | cut -d- -f1,2))
	python scripts/webquestions/copy_column_from_to.py 2:2 \
		working/$(TAGGER)-webquestions.dev.forest.conll \
		working/$*-webquestions.dev.forest.parsed.conll \
		> working/$*-webquestions.dev.forest.parsed.tmp.conll
	java -cp bin:lib/* deplambda.others.MergeConllAndGraphParserFormats \
		working/$*-webquestions.dev.forest.parsed.tmp.conll \
		working/$(TAGGER)-webquestions.dev.forest.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit \
		ssplit.newlineIsSentenceBreak always \
        tokenize.whitespace true \
		postprocess.removeMultipleRoots true \
		> working/$*-webquestions.dev.forest.parsed.json
	rm working/$*-webquestions.dev.forest.parsed.tmp.conll \

	python scripts/webquestions/copy_column_from_to.py 2:2 \
		working/$(TAGGER)-webquestions.train.forest.conll \
		working/$*-webquestions.train.forest.parsed.conll \
		> working/$*-webquestions.train.forest.parsed.tmp.conll
	java -cp bin:lib/* deplambda.others.MergeConllAndGraphParserFormats \
		working/$*-webquestions.train.forest.parsed.tmp.conll \
		working/$(TAGGER)-webquestions.train.forest.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit \
		ssplit.newlineIsSentenceBreak always \
        tokenize.whitespace true \
		postprocess.removeMultipleRoots true \
		> working/$*-webquestions.train.forest.parsed.json
	rm working/$*-webquestions.train.forest.parsed.tmp.conll \

	python scripts/webquestions/copy_column_from_to.py 2:2 \
		working/$(TAGGER)-webquestions.test.forest.conll \
		working/$*-webquestions.test.forest.parsed.conll \
		> working/$*-webquestions.test.forest.parsed.tmp.conll
	java -cp bin:lib/* deplambda.others.MergeConllAndGraphParserFormats \
		working/$*-webquestions.test.forest.parsed.tmp.conll \
		working/$(TAGGER)-webquestions.test.forest.json \
		| java -cp bin:lib/* deplambda.others.NlpPipeline \
		annotators tokenize,ssplit \
		ssplit.newlineIsSentenceBreak always \
        tokenize.whitespace true \
		postprocess.removeMultipleRoots true \
		> working/$*-webquestions.test.forest.parsed.json
	rm working/$*-webquestions.test.forest.parsed.tmp.conll \

deplambda_forest_%:
	cat working/$*-webquestions.dev.forest.parsed.json \
		| java -cp bin:lib/* deplambda.cli.RunForestTransformer \
		-definedTypesFile lib_data/ud.types.txt \
		-treeTransformationsFile lib_data/ud-tree-transformation-rules.proto.txt \
		-relationPrioritiesFile lib_data/ud-relation-priorities.proto.txt \
		-lambdaAssignmentRulesFile lib_data/ud-lambda-assignment-rules.proto.txt \
		-nthreads 20  \
		| python scripts/dependency_semantic_parser/remove_spurious_predicates_from_forest.py \
		> working/$*-webquestions.dev.forest.deplambda.json
	cat working/$*-webquestions.train.forest.parsed.json \
		| java -cp bin:lib/* deplambda.cli.RunForestTransformer \
		-definedTypesFile lib_data/ud.types.txt \
		-treeTransformationsFile lib_data/ud-tree-transformation-rules.proto.txt \
		-relationPrioritiesFile lib_data/ud-relation-priorities.proto.txt \
		-lambdaAssignmentRulesFile lib_data/ud-lambda-assignment-rules.proto.txt \
		-nthreads 20  \
		| python scripts/dependency_semantic_parser/remove_spurious_predicates_from_forest.py \
		> working/$*-webquestions.train.forest.deplambda.json
	cat working/$*-webquestions.test.forest.parsed.json \
		| java -cp bin:lib/* deplambda.cli.RunForestTransformer \
		-definedTypesFile lib_data/ud.types.txt \
		-treeTransformationsFile lib_data/ud-tree-transformation-rules.proto.txt \
		-relationPrioritiesFile lib_data/ud-relation-priorities.proto.txt \
		-lambdaAssignmentRulesFile lib_data/ud-lambda-assignment-rules.proto.txt \
		-nthreads 20  \
		| python scripts/dependency_semantic_parser/remove_spurious_predicates_from_forest.py \
		> working/$*-webquestions.test.forest.deplambda.json

merge_stanford_bistnopos_%:
	java -cp bin/:lib/* deplambda.others.MergeTwoForestsIfDisconnected \
		working/$*-bistnopos-webquestions.dev.forest.deplambda.json \
		< working/$*-stanford-webquestions.dev.forest.deplambda.json \
		> working/$*-stanford-bistnopos-webquestions.dev.forest.deplambda.json
	java -cp bin/:lib/* deplambda.others.MergeTwoForestsIfDisconnected \
		working/$*-bistnopos-webquestions.train.forest.deplambda.json \
		< working/$*-stanford-webquestions.train.forest.deplambda.json \
		> working/$*-stanford-bistnopos-webquestions.train.forest.deplambda.json
	java -cp bin/:lib/* deplambda.others.MergeTwoForestsIfDisconnected \
		working/$*-bistnopos-webquestions.test.forest.deplambda.json \
		< working/$*-stanford-webquestions.test.forest.deplambda.json \
		> working/$*-stanford-bistnopos-webquestions.test.forest.deplambda.json

extract_gold_graphs_bow_dev_%:
	mkdir -p data/gold_graphs/
	cat working/$*-webquestions.dev.forest.json \
    | java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
        data/freebase/schema/all_domains_schema.txt localhost \
        bow_question_graph \
        data/gold_graphs/$*_bow_without_merge_without_expand.dev \
        lib_data/dummy.txt \
        false \
        false \
        > data/gold_graphs/$*_bow_without_merge_without_expand.dev.answers.txt
	cat working/$*-webquestions.dev.stanford.forest.json \
    | java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
        data/freebase/schema/all_domains_schema.txt localhost \
        bow_question_graph \
        data/gold_graphs/$*_bow_with_merge_without_expand.dev \
        lib_data/dummy.txt \
        true \
        false \
	> data/gold_graphs/$*_bow_with_merge_without_expand.dev.answers.txt

extract_gold_graphs_bow_%:
	mkdir -p data/gold_graphs/
	cat working/$*-webquestions.train.forest.deplambda.json \
        working/$*-webquestions.dev.forest.deplambda.json \
    | java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
        data/freebase/schema/all_domains_schema.txt localhost \
        bow_question_graph \
        data/gold_graphs/$*_bow_without_merge_without_expand.full \
        lib_data/dummy.txt \
        false \
        false \
        > data/gold_graphs/$*_bow_without_merge_without_expand.full.answers.txt
	#cat working/$*-stanford-webquestions.train.forest.deplambda.json \
    #    working/$*-stanford-webquestions.dev.forest.deplambda.json \
    #| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
    #    data/freebase/schema/all_domains_schema.txt localhost \
    #    bow_question_graph \
    #    data/gold_graphs/$*_bow_with_merge_without_expand.full \
    #    lib_data/dummy.txt \
    #    true \
    #    false \
	#	> data/gold_graphs/$*_bow_with_merge_without_expand.full.answers.txt

extract_gold_graphs_dependency_dev_%:
	cat working/$*-webquestions.dev.forest.json \
		| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
        data/freebase/schema/all_domains_schema.txt localhost \
        dependency_question_graph \
        data/gold_graphs/$*_dependency_without_merge_without_expand.dev \
        lib_data/dummy.txt \
        false \
        false \
        > data/gold_graphs/$*_dependency_without_merge_without_expand.dev.answers.txt
	cat working/$*-webquestions.dev.forest.json \
		| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
        data/freebase/schema/all_domains_schema.txt localhost \
        dependency_question_graph \
        data/gold_graphs/$*_dependency_with_merge_without_expand.dev \
        lib_data/dummy.txt \
        true \
        false \
        > data/gold_graphs/$*_dependency_with_merge_without_expand.dev.answers.txt

extract_gold_graphs_dependency_hyperexpand_%:
	cat working/$*-webquestions.train.forest.deplambda.json \
        working/$*-webquestions.dev.forest.deplambda.json \
	| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   		data/freebase/schema/all_domains_schema.txt localhost \
        dependency_question_graph \
		data/gold_graphs/$*_dependency_with_hyperexpand.full \
		lib_data/dummy.txt \
	    false \
		false \
		true \
		> data/gold_graphs/$*_dependency_with_hyperexpand.full.answers.txt

extract_gold_graphs_dependency_%:
	cat working/$*-webquestions.train.forest.json \
        working/$*-webquestions.dev.forest.json \
    | java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
        data/freebase/schema/all_domains_schema.txt localhost \
        dependency_question_graph \
        data/gold_graphs/$*_dependency_without_merge_without_expand.full \
        lib_data/dummy.txt \
        false \
        false \
        > data/gold_graphs/$*_dependency_without_merge_without_expand.full.answers.txt
	cat working/$*-webquestions.train.forest.json \
        working/$*-webquestions.dev.forest.json \
    | java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
        data/freebase/schema/all_domains_schema.txt localhost \
        dependency_question_graph \
        data/gold_graphs/$*_dependency_with_merge_without_expand.full \
        lib_data/dummy.txt \
        true \
        false \
        > data/gold_graphs/$*_dependency_with_merge_without_expand.full.answers.txt

extract_gold_graphs_deplambda_dev_%:
	cat working/$*-webquestions.dev.forest.deplambda.json \
		| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   		data/freebase/schema/all_domains_schema.txt localhost \
		dependency_lambda \
		data/gold_graphs/$*_deplambda_with_merge_with_expand.dev \
		lib_data/dummy.txt \
	   	true \
		true \
		> data/gold_graphs/$*_deplambda_with_merge_with_expand.dev.answers.txt
	cat working/$*-webquestions.dev.forest.deplambda.json \
		| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   		data/freebase/schema/all_domains_schema.txt localhost \
	   	dependency_lambda \
		data/gold_graphs/$*_deplambda_without_merge_with_expand.dev \
		lib_data/dummy.txt \
	   	false \
		true \
		> data/gold_graphs/$*_deplambda_without_merge_with_expand.dev.answers.txt
	cat working/$*-webquestions.dev.forest.deplambda.json \
		| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   		data/freebase/schema/all_domains_schema.txt localhost \
		dependency_lambda \
		data/gold_graphs/$*_deplambda_with_merge_without_expand.dev \
		lib_data/dummy.txt \
	   	true \
		false \
		> data/gold_graphs/$*_deplambda_with_merge_without_expand.dev.answers.txt
	cat working/$*-webquestions.dev.forest.deplambda.json \
		| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   		data/freebase/schema/all_domains_schema.txt localhost \
		dependency_lambda \
		data/gold_graphs/$*_deplambda_without_merge_without_expand.dev \
		lib_data/dummy.txt \
	   	false \
		false \
		> data/gold_graphs/$*_deplambda_without_merge_without_expand.dev.answers.txt

extract_gold_graphs_deplambda_hyperexpand_%:
	cat working/$*-webquestions.train.forest.deplambda.json \
        working/$*-webquestions.dev.forest.deplambda.json \
	| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   		data/freebase/schema/all_domains_schema.txt localhost \
		dependency_lambda \
		data/gold_graphs/$*_deplambda_with_hyperexpand.full \
		lib_data/dummy.txt \
	    false \
		false \
		true \
		> data/gold_graphs/$*_deplambda_with_hyperexpand.full.answers.txt

extract_gold_graphs_deplambda_%:
	cat working/$*-webquestions.train.forest.deplambda.json \
        working/$*-webquestions.dev.forest.deplambda.json \
	| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   		data/freebase/schema/all_domains_schema.txt localhost \
		dependency_lambda \
		data/gold_graphs/$*_deplambda_with_merge_with_expand.full \
		lib_data/dummy.txt \
	   	true \
		true \
		> data/gold_graphs/$*_deplambda_with_merge_with_expand.full.answers.txt
	#cat working/$*-webquestions.train.forest.deplambda.json \
    #    working/$*-webquestions.dev.forest.deplambda.json \
	#| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   	#	data/freebase/schema/all_domains_schema.txt localhost \
	#   	dependency_lambda \
	#	data/gold_graphs/$*_deplambda_without_merge_with_expand.full \
	#	lib_data/dummy.txt \
	#   	false \
	#	true \
		> data/gold_graphs/$*_deplambda_without_merge_with_expand.full.answers.txt
	#cat working/$*-webquestions.train.forest.deplambda.json \
    #    working/$*-webquestions.dev.forest.deplambda.json \
	#| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   	#	data/freebase/schema/all_domains_schema.txt localhost \
	#	dependency_lambda \
	#	data/gold_graphs/$*_deplambda_with_merge_without_expand.full \
	#	lib_data/dummy.txt \
	#   	true \
	#	false \
	#	> data/gold_graphs/$*_deplambda_with_merge_without_expand.full.answers.txt
	#cat working/$*-webquestions.train.forest.deplambda.json \
        #working/$*-webquestions.dev.forest.deplambda.json \
	#| java -cp bin:lib/* in.sivareddy.scripts.EvaluateGraphParserOracleUsingGoldMidAndGoldRelations \
   	#	data/freebase/schema/all_domains_schema.txt localhost \
	#   	dependency_lambda \
	#	data/gold_graphs/$*_deplambda_without_merge_without_expand.full \
	#	lib_data/dummy.txt \
	#  	false \
	#	false \
	#	> data/gold_graphs/$*_deplambda_without_merge_without_expand.full.answers.txt

bow_supervised_without_merge_without_expand_%:
	rm -rf ../working/$*_bow_supervised_without_merge_without_expand
	mkdir -p ../working/$*_bow_supervised_without_merge_without_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
    -pointWiseF1Threshold 0.2 \
    -semanticParseKey dependency_lambda \
    -schema data/freebase/schema/all_domains_schema.txt \
    -relationTypesFile lib_data/dummy.txt \
    -lexicon lib_data/dummy.txt \
    -domain "http://rdf.freebase.com" \
    -typeKey "fb:type.object.type" \
    -nthreads 20 \
    -trainingSampleSize 2000 \
    -iterations 10 \
    -nBestTrainSyntacticParses 1 \
    -nBestTestSyntacticParses 1 \
    -nbestGraphs 100 \
    -forestSize 10 \
    -ngramLength 2 \
    -useSchema true \
    -useKB true \
    -addBagOfWordsGraph true \
    -ngramGrelPartFlag true \
    -addOnlyBagOfWordsGraph true \
    -groundFreeVariables false \
    -groundEntityVariableEdges false \
    -groundEntityEntityEdges false \
    -useEmptyTypes false \
    -ignoreTypes false \
    -urelGrelFlag false \
    -urelPartGrelPartFlag false \
    -utypeGtypeFlag false \
    -gtypeGrelFlag false \
    -wordGrelPartFlag false \
    -wordGrelFlag false \
    -eventTypeGrelPartFlag false \
    -argGrelPartFlag false \
    -argGrelFlag false \
    -stemMatchingFlag false \
    -mediatorStemGrelPartMatchingFlag false \
    -argumentStemMatchingFlag false \
    -argumentStemGrelPartMatchingFlag false \
    -graphIsConnectedFlag false \
    -graphHasEdgeFlag true \
    -countNodesFlag false \
    -edgeNodeCountFlag false \
    -duplicateEdgesFlag true \
    -grelGrelFlag true \
    -useLexiconWeightsRel false \
    -useLexiconWeightsType false \
    -validQueryFlag true \
    -useGoldRelations true \
    -evaluateOnlyTheFirstBest true \
    -evaluateBeforeTraining false \
    -entityScoreFlag true \
    -entityWordOverlapFlag false \
    -initialEdgeWeight -0.5 \
    -initialTypeWeight -2.0 \
    -initialWordWeight -0.05 \
    -stemFeaturesWeight 0.05 \
    -endpoint localhost \
    -supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
    -goldParsesFile data/gold_graphs/$*_bow_without_merge_without_expand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
    -devFile working/$*-webquestions.dev.forest.deplambda.json \
    -logFile ../working/$*_bow_supervised_without_merge_without_expand/all.log.txt \
    > ../working/$*_bow_supervised_without_merge_without_expand/all.txt

test_bow_supervised_without_merge_without_expand_%:
	rm -rf ../working/test_bow_supervised_without_merge_without_expand_$*
	mkdir -p ../working/test_bow_supervised_without_merge_without_expand_$*
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
    -pointWiseF1Threshold 0.2 \
    -semanticParseKey dependency_lambda \
    -schema data/freebase/schema/all_domains_schema.txt \
    -relationTypesFile lib_data/dummy.txt \
    -lexicon lib_data/dummy.txt \
    -domain "http://rdf.freebase.com" \
    -typeKey "fb:type.object.type" \
    -nthreads 20 \
    -trainingSampleSize 2000 \
    -iterations 10 \
    -nBestTrainSyntacticParses 1 \
    -nBestTestSyntacticParses 1 \
    -nbestGraphs 100 \
    -forestSize 10 \
    -ngramLength 2 \
    -useSchema true \
    -useKB true \
    -addBagOfWordsGraph true \
    -ngramGrelPartFlag true \
    -addOnlyBagOfWordsGraph true \
    -groundFreeVariables false \
    -groundEntityVariableEdges false \
    -groundEntityEntityEdges false \
    -useEmptyTypes false \
    -ignoreTypes false \
    -urelGrelFlag false \
    -urelPartGrelPartFlag false \
    -utypeGtypeFlag false \
    -gtypeGrelFlag false \
    -wordGrelPartFlag false \
    -wordGrelFlag false \
    -eventTypeGrelPartFlag false \
    -argGrelPartFlag false \
    -argGrelFlag false \
    -stemMatchingFlag false \
    -mediatorStemGrelPartMatchingFlag false \
    -argumentStemMatchingFlag false \
    -argumentStemGrelPartMatchingFlag false \
    -graphIsConnectedFlag false \
    -graphHasEdgeFlag true \
    -countNodesFlag false \
    -edgeNodeCountFlag false \
    -duplicateEdgesFlag true \
    -grelGrelFlag true \
    -useLexiconWeightsRel false \
    -useLexiconWeightsType false \
    -validQueryFlag true \
    -useGoldRelations true \
    -evaluateOnlyTheFirstBest true \
    -evaluateBeforeTraining false \
    -entityScoreFlag true \
    -entityWordOverlapFlag false \
    -initialEdgeWeight -0.5 \
    -initialTypeWeight -2.0 \
    -initialWordWeight -0.05 \
    -stemFeaturesWeight 0.05 \
    -endpoint localhost \
    -supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
    -goldParsesFile data/gold_graphs/$*_bow_without_merge_without_expand.full.ser \
    -devFile working/$*-webquestions.dev.forest.deplambda.json \
    -testFile working/$*-webquestions.test.forest.deplambda.json \
    -logFile ../working/test_bow_supervised_without_merge_without_expand_$*/all.log.txt \
    > ../working/test_bow_supervised_without_merge_without_expand_$*/all.txt

dependency_without_merge_without_expand_%:
	rm -rf ../working/$*_dependency_without_merge_without_expand
	mkdir -p ../working/$*_dependency_without_merge_without_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_question_graph \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes false \
	-urelGrelFlag true \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag true \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel true \
	-useLexiconWeightsType true \
	-validQueryFlag true \
	-useGoldRelations true \
	-evaluateOnlyTheFirstBest true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-allowMerging false \
	-handleEventEventEdges true \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -supervisedCorpus "working/$*-webquestions.train.forest.json" \
	-goldParsesFile data/gold_graphs/$*_dependency_without_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.json"  \
	-logFile ../working/$*_dependency_without_merge_without_expand/all.log.txt \
	> ../working/$*_dependency_without_merge_without_expand/all.txt

dependency_with_merge_without_expand_%:
	rm -rf ../working/$*_dependency_with_merge_without_expand
	mkdir -p ../working/$*_dependency_with_merge_without_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_question_graph \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes false \
	-urelGrelFlag true \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag true \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel true \
	-useLexiconWeightsType true \
	-validQueryFlag true \
	-useGoldRelations true \
	-evaluateOnlyTheFirstBest true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-allowMerging true \
	-handleEventEventEdges true \
	-initialEdgeWeight 1.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-goldParsesFile data/gold_graphs/$*_dependency_with_merge_without_expand.full.ser \
    -supervisedCorpus "working/$*-webquestions.train.forest.json" \
	-devFile "working/$*-webquestions.dev.forest.json"  \
	-logFile ../working/$*_dependency_with_merge_without_expand/all.log.txt \
	> ../working/$*_dependency_with_merge_without_expand/all.txt

test_dependency_with_merge_without_expand_%:
	rm -rf ../working/$*_test_dependency_with_merge_without_expand
	mkdir -p ../working/$*_test_dependency_with_merge_without_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_question_graph \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes false \
	-urelGrelFlag true \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag true \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel true \
	-useLexiconWeightsType true \
	-validQueryFlag true \
	-useGoldRelations true \
	-evaluateOnlyTheFirstBest true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-allowMerging true \
	-handleEventEventEdges true \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
   	-supervisedCorpus "working/$*-webquestions.train.forest.json;working/$*-webquestions.dev.forest.json" \
	-goldParsesFile data/gold_graphs/$*_dependency_with_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.json"  \
	-testFile "working/$*-webquestions.test.forest.json"  \
	-logFile ../working/$*_test_dependency_with_merge_without_expand/all.log.txt \
	> ../working/$*_test_dependency_with_merge_without_expand/all.txt

deplambda_without_merge_with_expand_%:
	rm -rf ../working/$*_deplambda_without_merge_with_expand
	mkdir -p ../working/$*_deplambda_without_merge_with_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag true \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel true \
	-useLexiconWeightsType true \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_with_expand.full.ser \
    -devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_with_expand/all.log.txt \
	> ../working/$*_deplambda_without_merge_with_expand/all.txt

deplambda_with_merge_with_expand.4.3_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.4.3
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.4.3
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.4.3/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.4.3/all.txt

test_deplambda_with_merge_with_expand.21_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand.21
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand.21
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand.21/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand.21/all.txt

deplambda_with_merge_with_expand.22_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.22
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.22
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.22/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.22/all.txt

deplambda_with_hyperexpand.22_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.22
	mkdir -p ../working/$*_deplambda_with_hyperexpand.22
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.22/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.22/all.txt

deplambda_with_hyperexpand.22.stem_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.22.stem
	mkdir -p ../working/$*_deplambda_with_hyperexpand.22.stem
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.22.stem/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.22.stem/all.txt

deplambda_without_merge_without_expand.23_%:
	rm -rf ../working/$*_deplambda_without_merge_without_expand.23
	mkdir -p ../working/$*_deplambda_without_merge_without_expand.23
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_without_expand.23/all.log.txt \
	> ../working/$*_deplambda_without_merge_without_expand.23/all.txt

deplambda_with_merge_with_expand.23_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.23
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.23
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.23/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.23/all.txt

deplambda_with_merge_with_expand.24_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.24
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.24
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.24/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.24/all.txt

deplambda_with_hyperexpand.24_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.24
	mkdir -p ../working/$*_deplambda_with_hyperexpand.24
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.24/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.24/all.txt

deplambda_without_merge_with_expand.24_%:
	rm -rf ../working/$*_deplambda_without_merge_with_expand.24
	mkdir -p ../working/$*_deplambda_without_merge_with_expand.24
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_with_expand.24/all.log.txt \
	> ../working/$*_deplambda_without_merge_with_expand.24/all.txt

deplambda_without_merge_without_expand.24_%:
	rm -rf ../working/$*_deplambda_without_merge_without_expand.24
	mkdir -p ../working/$*_deplambda_without_merge_without_expand.24
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_without_expand.24/all.log.txt \
	> ../working/$*_deplambda_without_merge_without_expand.24/all.txt

deplambda_without_merge_without_expand.26_%:
	rm -rf ../working/$*_deplambda_without_merge_without_expand.26
	mkdir -p ../working/$*_deplambda_without_merge_without_expand.26
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 20 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_without_expand.26/all.log.txt \
	> ../working/$*_deplambda_without_merge_without_expand.26/all.txt

deplambda_without_merge_without_expand.25_%:
	rm -rf ../working/$*_deplambda_without_merge_without_expand.25
	mkdir -p ../working/$*_deplambda_without_merge_without_expand.25
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_without_expand.25/all.log.txt \
	> ../working/$*_deplambda_without_merge_without_expand.25/all.txt

deplambda_with_merge_with_expand.25_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.25
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.25
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.25/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.25/all.txt


test_deplambda_with_merge_with_expand.20_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand.20
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand.20
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand.20/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand.20/all.txt

deplambda_without_merge_with_expand.27_%:
	rm -rf ../working/$*_deplambda_without_merge_with_expand.27
	mkdir -p ../working/$*_deplambda_without_merge_with_expand.27
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_with_expand.27/all.log.txt \
	> ../working/$*_deplambda_without_merge_with_expand.27/all.txt

deplambda_without_merge_with_expand.28_%:
	rm -rf ../working/$*_deplambda_without_merge_with_expand.28
	mkdir -p ../working/$*_deplambda_without_merge_with_expand.28
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_with_expand.28/all.log.txt \
	> ../working/$*_deplambda_without_merge_with_expand.28/all.txt

deplambda_without_merge_with_expand.29_%:
	rm -rf ../working/$*_deplambda_without_merge_with_expand.29
	mkdir -p ../working/$*_deplambda_without_merge_with_expand.29
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag true \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_with_expand.29/all.log.txt \
	> ../working/$*_deplambda_without_merge_with_expand.29/all.txt

deplambda_without_merge_without_expand.30_%:
	rm -rf ../working/$*_deplambda_without_merge_without_expand.30
	mkdir -p ../working/$*_deplambda_without_merge_without_expand.30
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-questionTypeGrelPartFlag true \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_without_expand.30/all.log.txt \
	> ../working/$*_deplambda_without_merge_without_expand.30/all.txt

deplambda_without_merge_with_expand.30_%:
	rm -rf ../working/$*_deplambda_without_merge_with_expand.30
	mkdir -p ../working/$*_deplambda_without_merge_with_expand.30
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-questionTypeGrelPartFlag true \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_with_expand.30/all.log.txt \
	> ../working/$*_deplambda_without_merge_with_expand.30/all.txt

deplambda_with_merge_without_expand.30_%:
	rm -rf ../working/$*_deplambda_with_merge_without_expand.30
	mkdir -p ../working/$*_deplambda_with_merge_without_expand.30
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-questionTypeGrelPartFlag true \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_without_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_without_expand.30/all.log.txt \
	> ../working/$*_deplambda_with_merge_without_expand.30/all.txt

deplambda_with_merge_with_expand.30_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.30
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.30
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-questionTypeGrelPartFlag true \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.30/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.30/all.txt

deplambda_with_hyperexpand.30_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.30
	mkdir -p ../working/$*_deplambda_with_hyperexpand.30
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-questionTypeGrelPartFlag true \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.00 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.30/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.30/all.txt

deplambda_with_merge_with_expand.31_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.31
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.31
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-useHyperExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.31/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.31/all.txt

deplambda_with_hyperexpand.31_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.31
	mkdir -p ../working/$*_deplambda_with_hyperexpand.31
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.31/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.31/all.txt

deplambda_with_hyperexpand.31.stem_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.31.stem
	mkdir -p ../working/$*_deplambda_with_hyperexpand.31.stem
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.31.stem/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.31.stem/all.txt

deplambda_with_hyperexpand.32_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.32
	mkdir -p ../working/$*_deplambda_with_hyperexpand.32
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.32/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.32/all.txt

test_deplambda_with_hyperexpand.32_%:
	rm -rf ../working/test_deplambda_with_hyperexpand.32_$*
	mkdir -p ../working/test_deplambda_with_hyperexpand.32_$*
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 20 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-testFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/test_deplambda_with_hyperexpand.32_$*/all.log.txt \
	> ../working/test_deplambda_with_hyperexpand.32_$*/all.txt

dependency_with_hyperexpand.32_%:
	rm -rf ../working/$*_dependency_with_hyperexpand.32
	mkdir -p ../working/$*_dependency_with_hyperexpand.32
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_question_graph \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_dependency_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_dependency_with_hyperexpand.32/all.log.txt \
	> ../working/$*_dependency_with_hyperexpand.32/all.txt

test_dependency_with_hyperexpand.32_%:
	rm -rf ../working/test_dependency_with_hyperexpand.32_$*
	mkdir -p ../working/test_dependency_with_hyperexpand.32_$*
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_question_graph \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_dependency_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-testFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/test_dependency_with_hyperexpand.32_$*/all.log.txt \
	> ../working/test_dependency_with_hyperexpand.32_$*/all.txt

deplambda_with_hyperexpand.32.stem_%:
	rm -rf ../working/$*_deplambda_with_hyperexpand.32.stem
	mkdir -p ../working/$*_deplambda_with_hyperexpand.32.stem
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_hyperexpand.32.stem/all.log.txt \
	> ../working/$*_deplambda_with_hyperexpand.32.stem/all.txt

test_deplambda_with_hyperexpand.32.stem_%:
	rm -rf ../working/test_deplambda_with_hyperexpand.32.stem_$*
	mkdir -p ../working/test_deplambda_with_hyperexpand.32.stem_$*
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges false \
	-useExpand false \
	-useHyperExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_hyperexpand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-testFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/test_deplambda_with_hyperexpand.32.stem_$*/all.log.txt \
	> ../working/test_deplambda_with_hyperexpand.32.stem_$*/all.txt

deplambda_with_merge_with_expand.32.stem_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.32.stem
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.32.stem
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-useHyperExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.32.stem/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.32.stem/all.txt

deplambda_with_merge_with_expand.32_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.32
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.32
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-questionTypeGrelPartFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-useHyperExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight 0.0 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV;PRON" \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.32/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.32/all.txt


test_deplambda_with_merge_with_expand.19_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand.19
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand.19
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand.19/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand.19/all.txt


test_deplambda_with_merge_with_expand.18_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand.18
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand.18
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag false \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -evaluateOnlyTheFirstBest true \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand.18/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand.18/all.txt



test_deplambda_with_merge_with_expand.17_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand.17
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand.17
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand.17/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand.17/all.txt

deplambda_with_merge_with_expand.17_1_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.17_1
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.17_1
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.17_1/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.17_1/all.txt

deplambda_with_merge_with_expand.17_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.17
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.17
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 20 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ;ADP;ADV" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.17/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.17/all.txt

test_deplambda_with_merge_with_expand.16_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand.16
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand.16
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand.16/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand.16/all.txt

deplambda_with_merge_with_expand.16_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.16
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.16
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.16/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.16/all.txt

test_deplambda_with_merge_with_expand.15_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand.15
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand.15
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand.15/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand.15/all.txt

deplambda_with_merge_with_expand.15_1_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.15_1
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.15_1
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-loadModelFromFile ../working/$*_bow_supervised_without_merge_without_expand/all.log.txt.model.bestIteration \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.15_1/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.15_1/all.txt

deplambda_with_merge_with_expand.15_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.15
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.15
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-mostFrequentTypesFile data/freebase/stats/freebase_most_frequent_types.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useAnswerTypeQuestionWordFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.15/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.15/all.txt

deplambda_with_merge_with_expand.14_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.14
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.14
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
    -evaluateOnlyTheFirstBest true \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.14/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.14/all.txt



deplambda_with_merge_with_expand.13_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.13
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.13
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-contentWordPosTags "NOUN;VERB;ADJ" \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.13/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.13/all.txt


deplambda_with_merge_with_expand.12_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.12
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.12
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag false \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.12/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.12/all.txt

deplambda_with_merge_with_expand.11_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.11
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.11
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.11/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.11/all.txt

deplambda_with_merge_with_expand.10_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.10
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.10
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.10/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.10/all.txt



deplambda_with_merge_with_expand.9.1_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.9.1
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.9.1
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.9.1/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.9.1/all.txt

deplambda_with_merge_with_expand.8_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.8
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.8
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 20 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 1 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag false \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.8/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.8/all.txt


deplambda_with_merge_with_expand.6_%:
	rm -rf ../working/$*_deplambda_with_merge_with_expand.6
	mkdir -p ../working/$*_deplambda_with_merge_with_expand.6
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag false \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag false \
	-argGrelPartFlag false \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel false \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
	-supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
	-devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_with_expand.6/all.log.txt \
	> ../working/$*_deplambda_with_merge_with_expand.6/all.txt


deplambda_without_merge_without_expand_%:
	rm -rf ../working/$*_deplambda_without_merge_without_expand
	mkdir -p ../working/$*_deplambda_without_merge_without_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag false \
	-utypeGtypeFlag true \
	-gtypeGrelFlag false \
	-wordGrelPartFlag false \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel true \
	-useLexiconWeightsType true \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging false \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_without_merge_without_expand.full.ser \
    -devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_without_merge_without_expand/all.log.txt \
	> ../working/$*_deplambda_without_merge_without_expand/all.txt

deplambda_with_merge_without_expand_%:
	rm -rf ../working/$*_deplambda_with_merge_without_expand
	mkdir -p ../working/$*_deplambda_with_merge_without_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag true \
	-mediatorStemGrelPartMatchingFlag true \
	-argumentStemMatchingFlag true \
	-argumentStemGrelPartMatchingFlag true \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel true \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand false \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_without_expand.full.ser \
    -devFile "working/$*-webquestions.dev.forest.deplambda.json" \
	-logFile ../working/$*_deplambda_with_merge_without_expand/all.log.txt \
	> ../working/$*_deplambda_with_merge_without_expand/all.txt

test_deplambda_with_merge_with_expand_%:
	rm -rf ../working/$*_test_deplambda_with_merge_with_expand
	mkdir -p ../working/$*_test_deplambda_with_merge_with_expand
	java -Xms2048m -cp bin:lib/* in.sivareddy.graphparser.cli.RunGraphToQueryTrainingMain \
	-pointWiseF1Threshold 0.2 \
	-semanticParseKey dependency_lambda \
	-ccgLexiconQuestions lib_data/lexicon_specialCases_questions_vanilla.txt \
	-schema data/freebase/schema/all_domains_schema.txt \
	-relationTypesFile lib_data/dummy.txt \
	-lexicon lib_data/dummy.txt \
	-domain "http://rdf.freebase.com" \
	-typeKey "fb:type.object.type" \
	-nthreads 20 \
	-trainingSampleSize 2000 \
	-iterations 10 \
	-nBestTrainSyntacticParses 1 \
	-nBestTestSyntacticParses 1 \
	-nbestGraphs 100 \
	-forestSize 10 \
	-ngramLength 2 \
	-useSchema true \
	-useKB true \
	-addBagOfWordsGraph false \
	-ngramGrelPartFlag true \
	-groundFreeVariables false \
	-groundEntityVariableEdges false \
	-groundEntityEntityEdges false \
	-useEmptyTypes false \
	-ignoreTypes true \
	-urelGrelFlag true \
	-urelPartGrelPartFlag true \
	-utypeGtypeFlag false \
	-gtypeGrelFlag false \
	-wordGrelPartFlag true \
	-wordGrelFlag false \
	-eventTypeGrelPartFlag true \
	-argGrelPartFlag true \
	-argGrelFlag false \
	-stemMatchingFlag false \
	-mediatorStemGrelPartMatchingFlag false \
	-argumentStemMatchingFlag false \
	-argumentStemGrelPartMatchingFlag false \
	-graphIsConnectedFlag false \
	-graphHasEdgeFlag true \
	-countNodesFlag false \
	-edgeNodeCountFlag false \
	-duplicateEdgesFlag true \
	-grelGrelFlag true \
	-useLexiconWeightsRel true \
	-useLexiconWeightsType false \
	-validQueryFlag true \
	-useGoldRelations true \
	-allowMerging true \
	-handleEventEventEdges true \
	-useExpand true \
	-evaluateBeforeTraining false \
	-entityScoreFlag true \
	-entityWordOverlapFlag false \
	-initialEdgeWeight -0.5 \
	-initialTypeWeight -2.0 \
	-initialWordWeight -0.05 \
	-stemFeaturesWeight 0.05 \
	-endpoint localhost \
    -supervisedCorpus "working/$*-webquestions.train.forest.deplambda.json;working/$*-webquestions.dev.forest.deplambda.json" \
	-goldParsesFile data/gold_graphs/$*_deplambda_with_merge_with_expand.full.ser \
    -devFile "working/$*-webquestions.test.forest.deplambda.json" \
	-logFile ../working/$*_test_deplambda_with_merge_with_expand/all.log.txt \
	> ../working/$*_test_deplambda_with_merge_with_expand/all.txt
