from pathlib import Path
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
RECOVERY = ROOT / 'PMM' / 'Modules' / 'AIIO' / 'AIIO.SessionRecoveryService.ps1'


def classify_model(doc: dict) -> bool:
    schema = str(doc.get('schema') or '')
    if schema == 'PMM_AIIO_SESSION_RECOVERY_V1':
        return True
    if schema not in ('PMM_AI_RESPONSE_V2', 'PMM_AIIO_RESPONSE_V2'):
        return False
    return str(doc.get('recoverySchema') or '') == 'PMM_AIIO_SESSION_RECOVERY_V1'


def validate_source_contract():
    text = RECOVERY.read_text(encoding='utf-8-sig')
    body = text.split('function Test-PMMAIIOSessionRecoveryDocument', 1)[1].split('function Get-PMMAIIOResponsePackageHint', 1)[0]
    assert "$Response.PSObject.Properties['recoverySchema']" in body
    assert '$Response.recoverySchema' not in body
    assert "if(-not$markerProperty){return $false}" in body


def validate_router_model():
    candidate = {
        'schema': 'PMM_AI_RESPONSE_V2',
        'sessionId': 'AIIO-20260901-031515-e596cb69',
        'responseType': 'candidate-ready',
        'requests': [],
        'candidates': [{'path': 'solutions/example'}],
    }
    standard = {
        'schema': 'PMM_AI_RESPONSE_V2',
        'sessionId': 'AIIO-EXAMPLE',
        'responseType': 'needs-data',
        'requests': [],
        'candidates': [],
    }
    wrapped_recovery = {
        **standard,
        'recoverySchema': 'PMM_AIIO_SESSION_RECOVERY_V1',
        'recoveryId': 'recovery-example-01',
    }
    native_recovery = {
        'schema': 'PMM_AIIO_SESSION_RECOVERY_V1',
        'sessionId': 'AIIO-EXAMPLE',
        'recoveryId': 'recovery-example-01',
        'requests': [{}],
        'candidates': [],
    }
    theme = {'schema': 'PMM_THEME_AI_RESPONSE_V1'}

    assert not classify_model(candidate)
    assert not classify_model(standard)
    assert classify_model(wrapped_recovery)
    assert classify_model(native_recovery)
    assert not classify_model(theme)


def optional_real_candidate_regression():
    # When the conversation test artifact is present beside the repository,
    # verify the exact response shape that triggered the StrictMode regression.
    candidate_zip = ROOT.parent.parent / 'PMM_AI_RESPONSE_AIIO-20260901-031515-e596cb69_STEP_05_CANDIDATE.zip'
    if not candidate_zip.exists():
        return
    with zipfile.ZipFile(candidate_zip) as zf:
        doc = json.loads(zf.read('response.json').decode('utf-8-sig'))
    assert doc['schema'] == 'PMM_AI_RESPONSE_V2'
    assert doc['responseType'] == 'candidate-ready'
    assert 'recoverySchema' not in doc
    assert not classify_model(doc)


def main():
    validate_source_contract()
    validate_router_model()
    optional_real_candidate_regression()
    print('PMM_V131_AIIO_SESSION_RECOVERY_MODEL_OK')


if __name__ == '__main__':
    main()
