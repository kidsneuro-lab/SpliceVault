# Deep Linking URL Support

SpliceVault now supports deep linking via URL parameters, allowing direct access to specific gene/transcript/exon queries.

## URL Format

```
https://kidsneuro.shinyapps.io/splicevault?db=hg38&gene=DMD&tx=NM_001347423&exon=2&site=D
```

## URL Parameters

All parameters are **required** and **case-sensitive**.

### `db` - Database Selection

Specifies which database to query. Accepts the following values:
- `hg38_300krna` - 300K-RNA (hg38)
- `hg38` - Maps to 300K-RNA (hg38)
- `GRCh38` - Maps to 300K-RNA (hg38)
- `hg19_40krna` - 40K-RNA (hg19)
- `hg19` - Maps to 40K-RNA (hg19)
- `GRCh37` - Maps to 40K-RNA (hg19)

**Validation:**
- Cannot be blank
- Must be one of the accepted values above

### `gene` - HGNC Gene Name

Specifies the gene symbol (HGNC gene name).

**Examples:** `DMD`, `BRCA1`, `TP53`

**Validation:**
- Cannot be blank
- Must exist in the selected database

### `tx` - Transcript ID

Specifies the transcript identifier (RefSeq or Ensembl).

**Examples:** 
- RefSeq: `NM_001347423`, `NM_004006`
- Ensembl: `ENST00000357033`

**Version Handling:**
- If a version is included (e.g., `NM_001347423.1`), it will be automatically removed
- The transcript is matched by base ID only (e.g., `NM_001347423`)

**Transcript Type Detection:**
- RefSeq transcripts (starting with `NM_`, `NR_`, `XM_`, `XR_`) automatically select "RefSeq" type
- Ensembl transcripts (starting with `ENST`) automatically select "Ensembl" type

**Validation:**
- Cannot be blank
- Must exist for the specified gene in the selected database

### `exon` - Exon Number

Specifies the exon number to query.

**Examples:** `1`, `2`, `10`, `45`

**Validation:**
- Cannot be blank
- Must be a positive integer (>= 1)
- Must exist for the specified transcript

### `site` - Splice Site Type

Specifies whether to query the donor or acceptor splice site.

**Values:**
- `D` - Donor (3' end of exon)
- `A` - Acceptor (5' end of exon)

**Validation:**
- Cannot be blank
- Must be either `D` or `A`

## Example URLs

### Example 1: DMD Gene, Exon 2 Donor Site (hg38)
```
https://kidsneuro.shinyapps.io/splicevault?db=hg38&gene=DMD&tx=NM_001347423&exon=2&site=D
```

### Example 2: BRCA1 Gene, Exon 10 Acceptor Site (hg19)
```
https://kidsneuro.shinyapps.io/splicevault?db=hg19&gene=BRCA1&tx=NM_007294&exon=10&site=A
```

### Example 3: With Transcript Version (version will be removed)
```
https://kidsneuro.shinyapps.io/splicevault?db=GRCh38&gene=DMD&tx=NM_001347423.1&exon=2&site=D
```

### Example 4: Ensembl Transcript
```
https://kidsneuro.shinyapps.io/splicevault?db=hg38&gene=DMD&tx=ENST00000357033&exon=2&site=D
```

## Error Handling

The application will display error notifications in the following cases:

1. **Missing Parameters**: If any required parameter is missing
   - Error: "Missing required URL parameters: [parameter names]"

2. **Invalid Database**: If `db` parameter is not one of the accepted values
   - Error: "Invalid URL parameter 'db': [value]. Valid values are: hg38_300krna, hg38, GRCh38, hg19_40krna, hg19, GRCh37"

3. **Invalid Exon Number**: If `exon` is not a positive integer
   - Error: "URL parameter 'exon' must be >= 1. Got: [value]"

4. **Invalid Site**: If `site` is not 'D' or 'A'
   - Error: "Invalid URL parameter 'site': [value]. Valid values are: D (Donor), A (Acceptor)"

5. **Gene Not Found**: If the gene doesn't exist in the database
   - Error: "Gene not found in database: [gene name]"

6. **Transcript Not Found**: If the transcript doesn't exist for the gene
   - Error: "Transcript not found in database: [transcript ID]"

7. **Exon Not Found**: If the exon doesn't exist for the transcript
   - Error: "Exon not found for this transcript: [exon number]"

## Behavior

When valid URL parameters are provided:
1. The application switches to the "Gene/Transcript/Exon" tab
2. The database is set to the specified value
3. The transcript type is automatically detected and set
4. The splice site type is set to the specified value (Donor/Acceptor)
5. The gene, transcript, and exon are selected
6. The table is automatically generated and displayed

When invalid parameters are provided:
- An error notification is displayed at the top of the page
- The application loads with default settings
- The table is not automatically generated

## Notes

- All URL parameters are case-sensitive
- The order of parameters in the URL does not matter
- URL encoding should be applied if gene names or other values contain special characters
- The deep linking feature works with both the Gene/Transcript/Exon and Variant modes, but URL parameters only trigger the Gene/Transcript/Exon mode
