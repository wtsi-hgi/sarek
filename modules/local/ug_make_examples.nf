// modules/local/ug_make_examples.nf
process UG_MAKE_EXAMPLES {
    tag "$meta.id - ${interval.baseName}"
    label 'process_high'
    container "${params.container_make_examples}"
    scratch false 

    input:
    tuple val(meta), path(cram), path(crai), path(interval)
    path fasta
    path fai

    output:
    tuple val(meta), path("*_n*[!f].tfrecord.gz"), emit: examples
    tuple val(meta), path("*_n*[f].tfrecord.gz"), emit: gvcf_tfrecords

    script:
    """
    tool \
        --input "$cram" \
        --cram-index "$crai" \
        --output "${meta.id}_${interval.baseName}" \
        --reference "$fasta" \
        --bed "$interval" \
        --min-base-quality 5 \
        --min-mapq 5 \
        --cgp-min-count-snps 2 \
        --cgp-min-count-hmer-indels 2 \
        --cgp-min-count-non-hmer-indels 2 \
        --cgp-min-fraction-snps 0.12 \
        --cgp-min-fraction-hmer-indels 0.12 \
        --cgp-min-fraction-non-hmer-indels 0.06 \
        --cgp-min-mapping-quality 5 \
        --max-reads-per-region 1500 \
        --assembly-min-base-quality 0 \
        --gzip-output \
        --no-realigned-sam \
        --gvcf \
        --p-error 0.005 \
        --optimal-coverages "50" \
        --cycle-examples-min 100000 \
        --add-ins-size-channel \
        --add-proxy-support-to-non-hmer-insertion \
        --pragmatic \
        --bsnv-detection \
        --keep-duplicates
    """
}

