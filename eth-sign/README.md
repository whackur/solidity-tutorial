# ECDSA를 사용한 이더리움 서명 검증

이 프로젝트는 OpenZeppelin의 ECDSA 라이브러리를 사용하여 이더리움 서명(`eth_sign` 및 `personal_sign`)을 검증하는 방법을 보여줍니다.

## 개요

`SignatureVerifier` 컨트랙트는 다음 방법으로 생성된 서명을 검증하는 메서드를 제공합니다:

- **eth_sign**: 32바이트 해시를 서명합니다
- **personal_sign**: 임의 길이의 메시지를 서명합니다

두 방법 모두 EIP-191 형식을 사용하며, 서명 변조 공격을 방지하기 위해 `"\x19Ethereum Signed Message:\n"`을 앞에 추가합니다.

## 컨트랙트 함수

### eth_sign 함수

- `verifyEthSign(bytes32 messageHash, bytes signature)`: eth_sign 서명에서 서명자를 복구합니다
- `verifyEthSignSigner(bytes32 messageHash, bytes signature, address expectedSigner)`: 서명이 예상 서명자와 일치하는지 확인합니다
- `recoverEthSignSigner(bytes32 messageHash, bytes signature)`: 서명자를 복구하는 순수 함수입니다

### personal_sign 함수

- `verifyPersonalSign(bytes message, bytes signature)`: personal_sign 서명에서 서명자를 복구합니다
- `verifyPersonalSignSigner(bytes message, bytes signature, address expectedSigner)`: 서명이 예상 서명자와 일치하는지 확인합니다
- `recoverPersonalSignSigner(bytes message, bytes signature)`: 서명자를 복구하는 순수 함수입니다

## 서명 작동 방식

### eth_sign

1. 사용자가 32바이트 해시를 서명합니다
2. 지갑이 EIP-191 접두사를 추가합니다: `keccak256("\x19Ethereum Signed Message:\n32" + messageHash)`
3. 컨트랙트가 동일한 접두사가 붙은 해시를 재생성하여 서명자를 복구합니다

### personal_sign

1. 사용자가 임의의 데이터(문자열, 바이트)를 서명합니다
2. 지갑이 데이터를 해시하고 EIP-191 접두사를 추가합니다: `keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)`
3. 컨트랙트가 해시와 접두사를 재생성하여 서명자를 복구합니다

## 보안 참고사항

- 임의의 메시지를 서명할 때는 항상 `personal_sign`을 사용하세요
- EIP-191 접두사가 없는 원래의 `eth_sign`은 보안 취약점으로 인해 더 이상 사용되지 않습니다
- 최신 지갑은 두 방법 모두에 대해 자동으로 EIP-191 접두사를 추가합니다
- 이해하지 못하는 데이터에는 절대 서명하지 마세요
