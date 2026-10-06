//
// ULTIMA GENOMICS DeepVariant germline calling
//

/* 
 * Import the three UG-specific modules we created
 */
include { UG_MAKE_EXAMPLES         } from '../../../modules/local/ug_make_examples'
include { UG_CALL_VARIANTS         } from '../../../modules/local/ug_call_variants'
include { UG_POSTPROCESS_VARIANTS  } from '../../../modules/local/ug_postprocess_variants'

workflow BAM_VARIANT_CALLING_UG_DV {
    take:
    cram          // channel: [meta, cram, crai]
    fasta         // channel: [fasta]
    fasta_fai     // channel: [fasta_fai]
    intervals     // channel: [intervals, num_intervals]
    model         // channel: [model_checkpoint]
    dbsnp
    exome_intervals
    lcr_bed
    mappability_bed
    hmers_bed

    main:
    versions = Channel.empty()

    // 1. Combine CRAM and intervals for sharding
    // Result: [meta + num_intervals, cram, crai, interval_file]
    ch_make_examples_in = cram.combine(intervals)
        .map{ meta, cram, crai, intervals, num_intervals -> 
            [ meta + [ num_intervals:num_intervals ], cram, crai, intervals ]
        }

    // 2. STEP 1: Generate Tensors (Parallelized by shard)
    UG_MAKE_EXAMPLES (
        ch_make_examples_in,
        fasta,
        fasta_fai
    )
    //versions = versions.mix(UG_MAKE_EXAMPLES.out.versions)

    // 3. Collect shards by Sample ID
    // We group the shards here so CallVariants runs ONCE per sample
    ch_collected_examples = UG_MAKE_EXAMPLES.out.examples
        .map { meta, tfrecords ->
            [ groupKey(meta, meta.num_intervals), tfrecords ]
        }
        .groupTuple()
        .map { meta, tfrecord_lists ->
            [ meta, tfrecord_lists.flatten() ]
        }

    ch_collected_gvcf_tf = UG_MAKE_EXAMPLES.out.gvcf_tfrecords
        .map { meta, tfrecords ->
            [ groupKey(meta, meta.num_intervals), tfrecords ]
        }
        .groupTuple()
        .map { meta, tfrecord_lists ->
            [ meta, tfrecord_lists.flatten() ]
        }

    // 4. STEP 2: Call Variants (GPU Step)
    // Takes the list of sharded TFRecords as one input
    UG_CALL_VARIANTS (
        ch_collected_examples,
        model
    )

    // 5. STEP 3: Postprocess (Merge and create VCF)
    // Join call outputs with the gVCF TFRecords gathered in step 3
    ch_postprocess_in = UG_CALL_VARIANTS.out.call_output
        .join(ch_collected_gvcf_tf)

   // Extract CRAM path from [meta, cram, crai]
   ch_cram_file = cram.map { meta, cram, crai -> cram }

    UG_POSTPROCESS_VARIANTS (
        ch_postprocess_in,
        ch_cram_file,
        fasta,
        fasta_fai,
        dbsnp,
        exome_intervals,
        lcr_bed,
        mappability_bed,
        hmers_bed
    )

    emit:
    vcf      = UG_POSTPROCESS_VARIANTS.out.vcf
    gvcf     = UG_POSTPROCESS_VARIANTS.out.gvcf
    versions = versions
}

