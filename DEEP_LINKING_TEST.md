# Deep Linking Testing Guide

This document provides instructions for testing the deep linking feature in SpliceVault.

## Test Cases

### Test Case 1: Full URL with all parameters (RefSeq)
**URL:**
```
https://kidsneuro.shinyapps.io/splicevault?gene_id=DMD&tx_id=NM_001347423&exon=2&site=D
```

**Expected behavior:**
1. App should switch to "Gene/Transcript/Exon" tab
2. Gene input should be populated with "DMD"
3. Transcript type should be set to "RefSeq" (auto-detected from NM_ prefix)
4. Transcript input should be populated with "NM_001347423"
5. Exon input should be populated with exon 2
6. Site should be set to "Donor"
7. Table should be automatically generated

### Test Case 2: Full URL with all parameters (Ensembl)
**URL:**
```
https://kidsneuro.shinyapps.io/splicevault?gene_id=BRCA1&tx_id=ENST00000357654&exon=5&site=A
```

**Expected behavior:**
1. App should switch to "Gene/Transcript/Exon" tab
2. Gene input should be populated with "BRCA1"
3. Transcript type should be set to "Ensembl" (auto-detected from ENST prefix)
4. Transcript input should be populated with "ENST00000357654"
5. Exon input should be populated with exon 5
6. Site should be set to "Acceptor"
7. Table should be automatically generated

### Test Case 3: Partial URL (gene and transcript only)
**URL:**
```
https://kidsneuro.shinyapps.io/splicevault?gene_id=DMD&tx_id=NM_001347423
```

**Expected behavior:**
1. App should switch to "Gene/Transcript/Exon" tab
2. Gene input should be populated with "DMD"
3. Transcript type should be set to "RefSeq"
4. Transcript input should be populated with "NM_001347423"
5. Exon and site should use default values
6. Table should be automatically generated

### Test Case 4: Invalid parameters
**URL:**
```
https://kidsneuro.shinyapps.io/splicevault?gene_id=INVALID_GENE&tx_id=INVALID_TX&exon=999&site=X
```

**Expected behavior:**
1. App should switch to "Gene/Transcript/Exon" tab
2. Invalid parameters should fall back to defaults:
   - Gene: first gene in the list
   - Transcript: first transcript for that gene
   - Exon: first exon for that transcript/site combination
   - Site: current selection (Acceptor by default)
3. Table should be automatically generated with fallback values

### Test Case 5: No URL parameters (backward compatibility)
**URL:**
```
https://kidsneuro.shinyapps.io/splicevault
```

**Expected behavior:**
1. App should function normally without any deep linking behavior
2. Default tab should be shown (Variant tab)
3. No automatic table generation

## Manual Testing Steps

1. Open each test URL in a browser
2. Verify that the app loads correctly
3. Check that all input fields are populated as expected
4. Verify that the table is generated automatically (if applicable)
5. Check the browser console for any errors
6. Verify that the generated table shows the correct data for the specified parameters

## Logging

The deep linking feature includes debug logging. To view logs:
1. Check the Shiny server logs
2. Look for messages starting with "[DEBUG]" that indicate:
   - Deep linking parameters detected
   - Gene/transcript/exon/site values being used
   - Transcript type detection
   - Auto-triggering of table generation

## Notes

- The deep linking feature requires that the specified gene, transcript, exon, and site exist in the database
- If any parameter is invalid, the app will gracefully fall back to default values
- The feature is designed to work with both 300K-RNA (hg38) and 40K-RNA (hg19) databases
- The transcript type is automatically detected from the transcript ID prefix
