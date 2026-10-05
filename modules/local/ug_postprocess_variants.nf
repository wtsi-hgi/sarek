// modules/local/ug_postprocess_variants.nf

process UG_POSTPROCESS_VARIANTS {
    tag "$meta.id"
    label 'process_low'
    container "${params.container_postprocess}"
    publishDir "${params.outdir}/variants", mode: 'copy'

    input:
    tuple val(meta), path(call_output), path(gvcf_tfrecords)
    path cram
    path fasta
    path fai
    path dbsnp
    path exome_intervals
    path lcr_bed
    path mappability_bed
    path hmers_bed

    output:
    tuple val(meta), path("*[!g].vcf.gz"), emit: vcf
    tuple val(meta), path("*.g.vcf.gz"), emit: gvcf

    script:
    """
    set -xeo pipefail

    echo 'Defining filters...'

    printf "%b\n" \
        "LowQualInExome" \
        "QUAL < 7 and VARIANT_TYPE=='h-indel' and not vc.isFiltered() and vc.hasAttribute('EXOME')" \
        "LowQual" \
        "QUAL < 5 and VARIANT_TYPE=='h-indel' and not vc.isFiltered() and not vc.hasAttribute('EXOME')" \
        "LowQual" \
        "QUAL < 0 and VARIANT_TYPE=='non-h-indel' and not vc.isFiltered()" \
        "LowQual" \
        "QUAL < 0 and VARIANT_TYPE=='snp' and not vc.isFiltered()" \
        "LargeDeletion" \
        "REFLEN > 220 and vc.isFiltered()" \
        > filters.txt

    echo 'Extracting flow order...'

    gatk ViewSam \
        -I "$cram" \
        --HEADER_ONLY true \
        --ALIGNMENT_STATUS All \
        --PF_STATUS All \
        | grep "^@RG" \
        | awk '{for (i=1;i<=NF;i++){if (\$i ~/FO:/) {print substr(\$i,4,4)}}}' \
        | sed '1!d' \
        > flow_order.txt

    echo "Flow order: $(cat flow_order.txt)"

    echo 'Creating called-record list...'

    cat <<EOF > called_records.txt
${call_output.join('\n')}
EOF

    echo 'Creating gVCF record list...'

    cat <<EOF > gvcf_records.txt
${gvcf_tfrecords.join('\n')}
EOF

    echo 'Running UG post-processing...'

    ug_postproc \
        --infile @called_records.txt \
        --ref "$fasta" \
        --outfile "${meta.id}.vcf.gz" \
        --gvcf_outfile "${meta.id}.g.vcf.gz" \
        --nonvariant_site_tfrecord_path @gvcf_records.txt \
        --hcr_bed_file "ug_hcr.bed" \
        --consider_strand_bias \
        --flow_order "\$(cat flow_order.txt)" \
        --annotate \
        --bed_annotation_files "$exome_intervals,$lcr_bed,$mappability_bed,$hmers_bed" \
        --qual_filter 1 \
        --filter \
        --filters_file filters.txt \
        --dbsnp "$dbsnp"

    bcftools index -t "${meta.id}.vcf.gz"
    bcftools index -t "${meta.id}.g.vcf.gz"
    """
}
