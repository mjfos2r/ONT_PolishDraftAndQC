version 1.0
import "../tasks/Dorado.wdl" as DORADO
import "../tasks/BamUtils.wdl" as BAM
import "../tasks/Quast.wdl" as QUAST

workflow ONT_PolishDraftAndQC {

    meta {
        description: "Polish draft assemblies using Dorado and generate QC reports for the assembly."
    }

    input {
        String sample_id
        File? merged_bam
        File? sanitized_bam_in
        File reads
        File reference_fa
        File reference_gff
        File draft_assembly
    }

    # First things first, we need to make sure the bam header for our merged bam is sanitized. this is very important.
    Boolean have_sanitized = defined(sanitized_bam_in)
    Boolean have_merged = defined(merged_bam)

    # if neither are provided, fail out.
    if (!have_sanitized && !have_merged) {
        call Fail as FailNone { input: msg = "Must provide either sanitized_bam or merged_bam to proceed. Please check your inputs and try again!" }
    }

    # if only merged is provided, clean this bam file.
    # also coerce merged bam since the type checker is complaining.
    if (!have_sanitized && have_merged) { call BAM.FixBamHeaderRG as FixBAM { input: input_bam = select_first([merged_bam]) } }

    # Pick the sanitized bam to output back to the DataTable:
    File sanitized_bam_final = select_first([sanitized_bam_in, FixBAM.sanitized_bam])

    call DORADO.Dorado {
        input:
            reads = sanitized_bam_final,
            draft_asm = draft_assembly,
            sample_id = sample_id
    }

    # Make an Array[File] so our raw and polished assemblies are both in the final quast report.
    Array[File] assemblies = [ draft_assembly, Dorado.polished ]

    # now run quast on em
    call QUAST.Quast {
        input:
            assemblies = assemblies,
            reference_fa = reference_fa,
            reference_gff = reference_gff,
            reads = reads
    }

    output {
        File assembly_polished = Dorado.polished
        File quast_data = Quast.data
        File quast_icarus = Quast.icarus
        File quast_report = Quast.report
        File sanitized_bam = sanitized_bam_final
    }
}

task Fail {
    input { String msg }
    command <<<
        echo "~{msg}" 1>&2
        exit 1
    >>>
    runtime {
        cpu: 2
        memory: "4 GiB"
        disks: "local-disk 10 HDD"
        bootDiskSizeGb: 10
        preemptible: 0
        maxRetries: 1
        docker: "alpine:latest"
    }
}