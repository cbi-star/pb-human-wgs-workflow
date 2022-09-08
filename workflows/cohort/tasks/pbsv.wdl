version 1.0

#import "./common_bgzip_vcf.wdl" as bgzip_vcf
#import "./pbsv_gather_svsigs.wdl"
#import "../../common/structs.wdl"
#import "../../common/separate_data_and_index_files.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/cohort/tasks/common_bgzip_vcf.wdl" as bgzip_vcf
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/cohort/tasks/pbsv_gather_svsigs.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/separate_data_and_index_files.wdl"

task pbsv_call {
  input {
    Int threads = 32
    String extra = "--ccs -m 20 -A 3 -O 3"
    String loglevel = "INFO"

    String log_name = "pbsv_call.log"

    Array[File] cohort_affected_person_svsigs
    Array[File] cohort_unaffected_person_svsigs
    IndexedData reference
    String cohort_name
    String region

    String pbsv_vcf_name = "~{cohort_name}.~{reference.name}.~{region}.pbsv.vcf"
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(cohort_affected_person_svsigs, "GB") + size(cohort_unaffected_person_svsigs, "GB"))) + 20
#  Int disk_size = 200

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate pbsv
    echo "$(conda info)"

    (
      pbsv call ~{extra} \
        --log-level ~{loglevel} \
        --num-threads ~{threads} \
        ~{reference.datafile} ~{sep=" " cohort_affected_person_svsigs}  ~{sep=" " cohort_unaffected_person_svsigs} ~{pbsv_vcf_name}
    ) > ~{log_name} 2>&1

  >>>
  output {
    File log = "~{log_name}"
    File pbsv_vcf = "~{pbsv_vcf_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "64 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

task bcftools_concat_pbsv_vcf {
  input {
    String log_name = "bcftools_concat_pbsv_vcf.log"

    Array[File] calls
    Array[File] indices

    String cohort_name
    String? reference_name
    String pbsv_vcf_name = "~{cohort_name}.~{reference_name}.pbsv.vcf"

    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(calls, "GB") + size(indices, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate bcftools
    echo "$(conda info)"

    (bcftools concat -a -o ~{pbsv_vcf_name} ~{sep=" " calls}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File pbsv_vcf = "~{pbsv_vcf_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

workflow pbsv {
  input {
    Array[Array[Array[File]]] affected_person_svsigs
    Array[Array[Array[File]]] unaffected_person_svsigs
    IndexedData reference
    Array[String] regions
    String cohort_name
    String pb_conda_image
  }

  Array[File] flattened_affected_person_svsigs =   flatten(flatten(affected_person_svsigs))
  Array[File] flattened_unaffected_person_svsigs = flatten(flatten(unaffected_person_svsigs))

  call pbsv_call {
    input:
      cohort_name = cohort_name,
      region = regions[region_num],
      cohort_affected_person_svsigs = flattened_affected_person_svsigs,
      cohort_unaffected_person_svsigs = flattened_unaffected_person_svsigs,
      reference = reference,
      pb_conda_image = pb_conda_image
    }

  call bgzip_vcf.bgzip_vcf {
      input :
        vcf_input = pbsv_call.pbsv_vcf,
        pb_conda_image = pb_conda_image
    }

  call separate_data_and_index_files.separate_data_and_index_files {
    input:
      indexed_data_array = bgzip_vcf.vcf_gz_output
  }

  output {
    IndexedData pbsv_vcf = bgzip_vcf.vcf_gz_output
  }
}
