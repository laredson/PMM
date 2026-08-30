<#
Fix Lab Case 001 recipe metadata helpers - Gawr Gura v5
========================================================

Case-specific knowledge lives in CKL. Binary work is performed by the generic
PMMFixLab.exe recipe engine. This file only exposes human-readable plans for the
five product variants and the temporary R1 engine-validation milestone.
#>

function Get-PMMFixLabGuraV5VariantPlan([string]$VariantId) {
  switch($VariantId){
    'original_fullreplacement' {
      return [pscustomobject]@{VariantId=$VariantId;Base='Current outfit identities -> full Gura + Gura_1 pelvis continuation';Summer='v02 -> full Gura + Gura_1 with static Evil/red material routing';Winter='v03 -> full Gura + Gura_1 + Gura_Hood';HairMode='Full replacement'}
    }
    'normal_locked' { return [pscustomobject]@{VariantId=$VariantId;Base='All current outfit identities -> full Gura + Gura_1';Summer='Locked normal';Winter='Locked normal';HairMode='Full replacement'} }
    'red_locked' { return [pscustomobject]@{VariantId=$VariantId;Base='All current outfit identities -> full Gura + Gura_1 with static red material routing';Summer='Locked red';Winter='Locked red';HairMode='Full replacement'} }
    'hooded_locked' { return [pscustomobject]@{VariantId=$VariantId;Base='All current outfit identities -> full Gura + Gura_1 + Gura_Hood';Summer='Locked hooded';Winter='Locked hooded';HairMode='Full replacement'} }
    'hair2_panties' { return [pscustomobject]@{VariantId=$VariantId;Base='Hair002 conditional bridge -> Gura base + separate Gura_1 Cloth component';Summer='Original _v02 / EvilGura conditional behavior retained';Winter='Original _v03 / Gura_Hood conditional behavior retained';HairMode='Only Hair 2 activates Gura; non-Hair2 stays vanilla';Note='Validated output retains visible panties and is documented as the Panties Version.'} }
    'core_reconstruction_r1' { return [pscustomobject]@{VariantId=$VariantId;Base='Generic recipe-engine current-provider reconstruction';Summer='Not included in R1';Winter='Not included in R1';HairMode='Full current-provider replacement';Note='Engineering milestone used to validate source PAK + Current Game Reference + small recipe -> locally reconstructed PAK. No golden output fixture is used.'} }
    default { throw ('Unknown Gawr Gura Fix Lab variant: '+$VariantId) }
  }
}
