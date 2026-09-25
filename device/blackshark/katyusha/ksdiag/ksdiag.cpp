/*
 * ksdiag - keystore2/KeyMint diagnostic for the katyusha TWRP bring-up.
 *
 * Works only with throwaway keys in keystore2's BLOB domain (stored in a file given on
 * the command line). It never touches vold/metadata keys.
 *
 *   ksdiag gen <file>   generate an AES-256-GCM key, print the authorizations KeyMint
 *                       enforces (OS version / patch levels etc.), save the blob
 *   ksdiag use <file>   begin a GCM encrypt with the saved blob, report the result
 *   ksdiag vold <dir>   READ-ONLY: compute vold's APPLICATION_ID for a vold key directory
 *                       (SHA512 of prefix||secdiscardable, empty secret) and only *begin*
 *                       a GCM DECRYPT with its keymaster_key_blob, then abort. Nothing is
 *                       decrypted, written or upgraded.
 *   ksdiag chars <dir>  READ-ONLY: IKeyMintDevice::getKeyCharacteristics() for a vold key
 *                       directory (with vold's APPLICATION_ID) - prints all key tags
 *   ksdiag genrr <file> like gen, but the throwaway key requests ROLLBACK_RESISTANCE
 *
 * Purpose: compare what KeyMint binds keys to in normal boot vs. recovery boot.
 */
#include <aidl/android/hardware/security/keymint/Algorithm.h>
#include <aidl/android/hardware/security/keymint/IKeyMintDevice.h>
#include <aidl/android/hardware/security/keymint/BlockMode.h>
#include <aidl/android/hardware/security/keymint/KeyPurpose.h>
#include <aidl/android/hardware/security/keymint/PaddingMode.h>
#include <aidl/android/hardware/security/keymint/SecurityLevel.h>
#include <aidl/android/hardware/security/keymint/Tag.h>
#include <aidl/android/system/keystore2/Domain.h>
#include <aidl/android/system/keystore2/IKeystoreService.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <openssl/sha.h>

#include <cstdio>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

namespace km = ::aidl::android::hardware::security::keymint;
namespace ks2 = ::aidl::android::system::keystore2;

static const char kService[] = "android.system.keystore2.IKeystoreService/default";

static km::KeyParameter P(km::Tag tag, km::KeyParameterValue v) {
    km::KeyParameter p;
    p.tag = tag;
    p.value = std::move(v);
    return p;
}

static void report(const char* what, const ndk::ScopedAStatus& st) {
    if (st.getExceptionCode() == EX_SERVICE_SPECIFIC)
        printf("%s: FAILED service-specific error %d\n", what, st.getServiceSpecificError());
    else
        printf("%s: FAILED %s\n", what, st.getDescription().c_str());
}

static const char* levelName(km::SecurityLevel l) {
    switch (l) {
        case km::SecurityLevel::SOFTWARE: return "SOFTWARE";
        case km::SecurityLevel::TRUSTED_ENVIRONMENT: return "TEE";
        case km::SecurityLevel::STRONGBOX: return "STRONGBOX";
        case km::SecurityLevel::KEYSTORE: return "KEYSTORE";
    }
    return "?";
}

static void printParam(const ks2::Authorization& a) {
    const auto& p = a.keyParameter;
    const char* name = nullptr;
    switch (p.tag) {
        case km::Tag::OS_VERSION: name = "OS_VERSION"; break;
        case km::Tag::OS_PATCHLEVEL: name = "OS_PATCHLEVEL"; break;
        case km::Tag::VENDOR_PATCHLEVEL: name = "VENDOR_PATCHLEVEL"; break;
        case km::Tag::BOOT_PATCHLEVEL: name = "BOOT_PATCHLEVEL"; break;
        case km::Tag::ORIGIN: name = "ORIGIN"; break;
        case km::Tag::ALGORITHM: name = "ALGORITHM"; break;
        case km::Tag::KEY_SIZE: name = "KEY_SIZE"; break;
        case km::Tag::BLOCK_MODE: name = "BLOCK_MODE"; break;
        case km::Tag::PURPOSE: name = "PURPOSE"; break;
        case km::Tag::MIN_MAC_LENGTH: name = "MIN_MAC_LENGTH"; break;
        case km::Tag::NO_AUTH_REQUIRED: name = "NO_AUTH_REQUIRED"; break;
        case km::Tag::CREATION_DATETIME: name = "CREATION_DATETIME"; break;
        case km::Tag::ROLLBACK_RESISTANCE: name = "ROLLBACK_RESISTANCE"; break;
        case km::Tag::EARLY_BOOT_ONLY: name = "EARLY_BOOT_ONLY"; break;
        case km::Tag::MAX_BOOT_LEVEL: name = "MAX_BOOT_LEVEL"; break;
        case km::Tag::STORAGE_KEY: name = "STORAGE_KEY"; break;
        case km::Tag::APPLICATION_ID: name = "APPLICATION_ID"; break;
        case km::Tag::USAGE_COUNT_LIMIT: name = "USAGE_COUNT_LIMIT"; break;
        default: break;
    }
    std::string val;
    using V = km::KeyParameterValue;
    switch (p.value.getTag()) {
        case V::integer: val = std::to_string(p.value.get<V::integer>()); break;
        case V::longInteger: val = std::to_string(p.value.get<V::longInteger>()); break;
        case V::dateTime: val = std::to_string(p.value.get<V::dateTime>()); break;
        case V::boolValue: val = p.value.get<V::boolValue>() ? "true" : "false"; break;
        case V::algorithm: val = std::to_string((int)p.value.get<V::algorithm>()); break;
        case V::blockMode: val = std::to_string((int)p.value.get<V::blockMode>()); break;
        case V::keyPurpose: val = std::to_string((int)p.value.get<V::keyPurpose>()); break;
        case V::origin: val = std::to_string((int)p.value.get<V::origin>()); break;
        default: val = "(type " + std::to_string((int)p.value.getTag()) + ")"; break;
    }
    if (name)
        printf("  %-10s %-18s = %s\n", levelName(a.securityLevel), name, val.c_str());
    else
        printf("  %-10s tag 0x%08x       = %s\n", levelName(a.securityLevel), (unsigned)p.tag,
               val.c_str());
}

int main(int argc, char** argv) {
    if (argc != 3 || (std::string(argv[1]) != "gen" && std::string(argv[1]) != "use" &&
                      std::string(argv[1]) != "vold" && std::string(argv[1]) != "chars" &&
                      std::string(argv[1]) != "genrr")) {
        fprintf(stderr, "usage: %s gen|use <blobfile> | vold <keydir>\n", argv[0]);
        return 2;
    }
    const std::string mode = argv[1], file = argv[2];

    ABinderProcess_startThreadPool();
    ndk::SpAIBinder binder(AServiceManager_waitForService(kService));
    auto ks = ks2::IKeystoreService::fromBinder(binder);
    if (!ks) { printf("cannot connect to keystore2\n"); return 1; }

    std::shared_ptr<ks2::IKeystoreSecurityLevel> sec;
    auto st = ks->getSecurityLevel(km::SecurityLevel::TRUSTED_ENVIRONMENT, &sec);
    if (!st.isOk()) { report("getSecurityLevel", st); return 1; }

    using V = km::KeyParameterValue;
    ks2::KeyDescriptor desc;
    desc.domain = ks2::Domain::BLOB;
    desc.nspace = 0;

    if (mode == "gen" || mode == "genrr") {
        std::vector<km::KeyParameter> params = {
            P(km::Tag::ALGORITHM, V::make<V::algorithm>(km::Algorithm::AES)),
            P(km::Tag::KEY_SIZE, V::make<V::integer>(256)),
            P(km::Tag::BLOCK_MODE, V::make<V::blockMode>(km::BlockMode::GCM)),
            P(km::Tag::PADDING, V::make<V::paddingMode>(km::PaddingMode::NONE)),
            P(km::Tag::MIN_MAC_LENGTH, V::make<V::integer>(128)),
            P(km::Tag::PURPOSE, V::make<V::keyPurpose>(km::KeyPurpose::ENCRYPT)),
            P(km::Tag::PURPOSE, V::make<V::keyPurpose>(km::KeyPurpose::DECRYPT)),
            P(km::Tag::NO_AUTH_REQUIRED, V::make<V::boolValue>(true)),
        };
        if (mode == "genrr")
            params.push_back(P(km::Tag::ROLLBACK_RESISTANCE, V::make<V::boolValue>(true)));
        ks2::KeyMetadata md;
        st = sec->generateKey(desc, std::nullopt, params, 0, {}, &md);
        if (!st.isOk()) { report("generateKey", st); return 1; }
        printf("generateKey: OK (security level %s)\nauthorizations:\n",
               levelName(md.keySecurityLevel));
        for (const auto& a : md.authorizations) printParam(a);
        if (!md.key.blob) { printf("no blob returned\n"); return 1; }
        std::ofstream(file, std::ios::binary)
                .write((const char*)md.key.blob->data(), md.key.blob->size());
        printf("blob (%zu bytes) saved to %s\n", md.key.blob->size(), file.c_str());
        return 0;
    }

    if (mode == "chars") {
        auto readAll = [](const std::string& f) {
            std::ifstream i(f, std::ios::binary);
            return std::vector<uint8_t>((std::istreambuf_iterator<char>(i)), {});
        };
        auto kblob = readAll(file + "/keymaster_key_blob");
        auto secd = readAll(file + "/secdiscardable");
        std::string prefix = "Android secdiscardable SHA512";
        prefix.resize(SHA512_CBLOCK);
        SHA512_CTX c;
        SHA512_Init(&c);
        SHA512_Update(&c, prefix.data(), prefix.size());
        SHA512_Update(&c, secd.data(), secd.size());
        std::vector<uint8_t> appId(SHA512_DIGEST_LENGTH);
        SHA512_Final(appId.data(), &c);
        ndk::SpAIBinder kb(AServiceManager_waitForService(
                "android.hardware.security.keymint.IKeyMintDevice/default"));
        auto kmd = km::IKeyMintDevice::fromBinder(kb);
        if (!kmd) { printf("cannot connect to KeyMint HAL\n"); return 1; }
        std::vector<km::KeyCharacteristics> chars;
        auto s3 = kmd->getKeyCharacteristics(kblob, appId, {}, &chars);
        if (!s3.isOk()) { report("getKeyCharacteristics", s3); return 1; }
        printf("getKeyCharacteristics: OK\n");
        for (const auto& kc : chars)
            for (const auto& p : kc.authorizations) {
                ks2::Authorization a;
                a.securityLevel = kc.securityLevel;
                a.keyParameter = p;
                printParam(a);
            }
        return 0;
    }

    if (mode == "vold") {
        auto readAll = [](const std::string& f) {
            std::ifstream i(f, std::ios::binary);
            return std::vector<uint8_t>((std::istreambuf_iterator<char>(i)), {});
        };
        auto kblob = readAll(file + "/keymaster_key_blob");
        auto secd = readAll(file + "/secdiscardable");
        auto enc = readAll(file + "/encrypted_key");
        printf("keymaster_key_blob %zu bytes, secdiscardable %zu bytes, encrypted_key %zu bytes\n",
               kblob.size(), secd.size(), enc.size());
        if (kblob.empty() || enc.size() < 12) { printf("missing key files\n"); return 1; }
        // vold: hashWithPrefix("Android secdiscardable SHA512", secdiscardable)
        std::string prefix = "Android secdiscardable SHA512";
        prefix.resize(SHA512_CBLOCK);
        SHA512_CTX c;
        SHA512_Init(&c);
        SHA512_Update(&c, prefix.data(), prefix.size());
        SHA512_Update(&c, secd.data(), secd.size());
        std::vector<uint8_t> appId(SHA512_DIGEST_LENGTH);
        SHA512_Final(appId.data(), &c);
        std::vector<uint8_t> nonce(enc.begin(), enc.begin() + 12);

        auto tryBegin = [&](const char* label, bool withAppId) {
            desc.blob = kblob;
            std::vector<km::KeyParameter> op = {
                P(km::Tag::PURPOSE, V::make<V::keyPurpose>(km::KeyPurpose::DECRYPT)),
                P(km::Tag::BLOCK_MODE, V::make<V::blockMode>(km::BlockMode::GCM)),
                P(km::Tag::PADDING, V::make<V::paddingMode>(km::PaddingMode::NONE)),
                P(km::Tag::MAC_LENGTH, V::make<V::integer>(128)),
                P(km::Tag::NONCE, V::make<V::blob>(nonce)),
            };
            if (withAppId) op.push_back(P(km::Tag::APPLICATION_ID, V::make<V::blob>(appId)));
            ks2::CreateOperationResponse r;
            auto s2 = sec->createOperation(desc, op, false, &r);
            if (!s2.isOk()) { report(label, s2); return; }
            printf("%s: OK (begin accepted)\n", label);
            if (r.upgradedBlob) printf("  NOTE: keystore2 reported an upgraded blob (not saved)\n");
            if (r.iOperation) r.iOperation->abort();
        };
        tryBegin("begin DECRYPT with vold APPLICATION_ID", true);
        tryBegin("begin DECRYPT without APPLICATION_ID", false);
        return 0;
    }

    std::ifstream in(file, std::ios::binary);
    std::vector<uint8_t> blob((std::istreambuf_iterator<char>(in)), {});
    if (blob.empty()) { printf("cannot read %s\n", file.c_str()); return 1; }
    desc.blob = blob;
    std::vector<km::KeyParameter> op = {
        P(km::Tag::PURPOSE, V::make<V::keyPurpose>(km::KeyPurpose::ENCRYPT)),
        P(km::Tag::BLOCK_MODE, V::make<V::blockMode>(km::BlockMode::GCM)),
        P(km::Tag::PADDING, V::make<V::paddingMode>(km::PaddingMode::NONE)),
        P(km::Tag::MAC_LENGTH, V::make<V::integer>(128)),
    };
    ks2::CreateOperationResponse resp;
    st = sec->createOperation(desc, op, false, &resp);
    if (!st.isOk()) { report("createOperation", st); return 1; }
    printf("createOperation: OK - blob from %s is usable here\n", file.c_str());
    if (resp.iOperation) resp.iOperation->abort();
    return 0;
}
