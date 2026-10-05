// modules/local/ug_call_variants.nf
process UG_CALL_VARIANTS {
    tag "$meta.id"
    label 'gpu'
    container "${params.container_call_variants}"

    input:
    tuple val(meta), path(examples)
    path model_checkpoint

    output:
    tuple val(meta), path("call_variants*.gz"), emit: call_output
    path "params.ini", emit: params
    path "call_variants*.log", emit: log

    script:
    def num_examples = examples.size()

    """
    set -eo pipefail

    printf "%b\n" "[RT classification]" \
        "onnxFileName = ${model_checkpoint}" \
        "useSerializedModel = 1" \
        "trtWorkspaceSizeMB = 2000" \
        "numInferTreadsPerGpu = 2" \
        "useGPUs = 1" \
        "gpuid = 0\n" \
        "[debug]" \
        "logFileFolder = .\n" \
        "[general]" \
        "tfrecord = 1" \
        "compressed = 1" \
        "outputInOneFile = 0" \
        "numUncomprThreads = 8" \
        "uncomprBufSizeGB = 1" \
        "outputFileName = call_variants" \
        "numConversionThreads = 2" \
        "numExampleFiles = ${num_examples}\n" > params.ini

    cat <<EOF | awk '{print "exampleFile" NR " = "\$0}' >> params.ini
${examples.join('\n')}
EOF

    call_variants --param params.ini --fp16
    """
}
