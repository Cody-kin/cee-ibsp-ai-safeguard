# Third-party notices / 第三方聲明

Cody-kin authorizes the project-specific source for public viewing. This does not relicense third-party material or establish a project-wide open-source license. Full applicable notices below are retained in `licenses/` or the component directory.

| Material | Verified provenance / treatment |
| --- | --- |
| ChirpStack configuration | Existing `05_chirpstack_lorawan_config/LICENSE` retained; MIT scope is that component |
| DFRobot DF2301Q drivers | Official [repository](https://github.com/DFRobot/DFRobot_DF2301Q/tree/f65e7324825b2d07a8ec14f5503191c26a90d640), Python raspberrypi driver. Nested copy is byte-identical; abbreviated copy removes documentation and UART debug logging. Original header restored; [MIT text](../licenses/DFRobot-MIT.txt) included |
| Geist Sans / Mono | Both local version-1.200 font blobs match the [Next.js v15.0.0 template](https://github.com/vercel/next.js/tree/v15.0.0/packages/create-next-app/templates/app/ts/app/fonts). [Geist 1.2.0 OFL](../licenses/Geist-1.2.0-OFL.txt) copied unchanged from its official release |
| Next.js template / favicon | Favicon matches the official v15.0.0 template blob. [Next.js MIT](../licenses/Nextjs-MIT.txt) included; this does not imply Vercel endorsement |
| iOS custom icon | Supplied project artwork retained under the author's publication authorization; EXIF inspected for personal metadata. Generated-looking filename is not a copyright registration or exclusive-ownership claim |
| busboy / streamsearch | npm lockfile omitted license metadata, but installed package LICENSE files grant MIT-style terms; exact notices retained in `licenses/`. node_modules is not distributed |
| Other npm/Python/hardware/container dependencies | Declared dependencies and lockfile, not bundled installed packages; preserve their own licenses when installing/distributing builds |
| YOLOv5 runtime | Integration code can fetch upstream via torch.hub; upstream source/weights are not bundled. Pin and review the exact runtime revision/license before deployment or redistribution of a combined build |
| Weights / approximately 2 GB dataset / training images | Excluded. No data-source, image-subject or redistribution clearance asserted |
| Student reports / assessments / log | Excluded; only technical citations and file hashes retained |

Verified blob IDs: Geist Mono `f2ae185cbfd16946a534d819e9eb03924abbcc49`; Geist Sans `1b62daacff96dad6584e71cd962051b82957c313`; favicon `718d6fea4835ec2d246af9800eddb7ffb276240c`.

局部 MIT、OFL 與套件聲明只適用各自元件；不擴大為整體授權。第三方作者與權利聲明保留，未把上游程式當作使用者獨自原創。模型／資料集仍不包含在公開範圍內。
