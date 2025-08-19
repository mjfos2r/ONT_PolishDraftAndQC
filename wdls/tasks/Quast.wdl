version 1.0

import "../structs/Structs.wdl"

task Quast {
    meta {
        description: "Task to generate assembly QC metrics using Quast and a reference genome"
        author: "Michael J. Foster"
    }
    parameter_meta {
        assemblies: "fastas for our draft assembly and polished assembly"
        reference_fa: "reference genome for misassembly determination"
        reference_gff: "gff file containing annotations for the reference."
        reads: "Fastq file containing the reads for our draft assembly"
    }

    input {
        Array[File] assemblies
        File reference_fa
        File reference_gff
        File reads
        RuntimeAttr? runtime_attr_override
    }
    Int disk_size = 365 + 2 * ceil(size(reads, "GB"))

    command <<<
        NPROC=$(awk '/^processor/{print}' /proc/cpuinfo | wc -l)
        mkdir -p quast_output
        quast.py \
            -o quast_output \
            -t "$NPROC" \
            -r "~{reference_fa}" \
            -g "~{reference_gff}" \
            --nanopore "~{reads}" \
            ~{sep=' ' assemblies}

        tar -czf quast.tar.gz quast_output/
    >>>

    output {
        File data = "quast.tar.gz"
        File icarus = "quast_output/icarus.html"
        File report = "quast_output/report.html"
    }

    #########################
    RuntimeAttr default_attr = object {
        cpu_cores:          16,
        mem_gb:             64,
        disk_gb:            disk_size,
        boot_disk_gb:       50,
        preemptible_tries:  0,
        max_retries:        0,
        docker:             "mjfos2r/quast:latest"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}