# Publication review / 發布審查

## Author authorization / 作者授權

Cody-kin explicitly confirms that the IBSP was completed individually, is unrelated to school/placement contractual restrictions, and authorizes direct public release. This resolves the earlier institutional/contributor clarification; no further school permission is requested. Attribution uses the public GitHub handle, not a student number or private mailbox. Third-party components remain separately attributed.

作者已明確確認一人完成、與學校／實習機構條款無關並授權公開。先前相關待確認項目已解除；不再要求額外機構同意。第三方元件仍依各自授權處理。

## Release contents / 發布內容

- Project source, bilingual README, architecture, 43-feature evidence matrix, 39-route index, tests and review documents.
- DFRobot MIT attribution restored to the abbreviated driver; full upstream license included. The nested copy matches upstream exactly; the abbreviated copy removes comments/docstrings and a UART debug log.
- Geist 1.200 binaries match the official Next.js v15.0.0 template blobs; matching Geist 1.2.0 OFL and Next.js MIT notices are included. The favicon also matches that template.
- The supplied custom iOS icon is retained under the author's project-material authorization. Its inspected EXIF contains orientation/resolution/color/dimension fields, not GPS, author, device or time fields. This does not represent copyright registration or a claim of exclusive rights in purely AI-generated elements.
- No raw reports, student IDs, signatures, identifiable training photographs, weights, dataset, nested Git history or live source credentials are included.

## Commit privacy / 提交隱私

The author requested that their private mailbox not be published. Earlier private commits used a personal email, so merely changing visibility or deleting text files would not solve the problem. The publication repository is prepared with a fresh history and GitHub noreply attribution; the original repository is preserved privately. GitHub's email-privacy setting was enabled to prevent future web commits from adding the private mailbox. This setting does not retroactively remove emails from other existing repositories.

用戶要求不公開私人郵箱，因此保留舊私人倉庫，以 noreply 郵箱建立新的發布歷史，而不是只刪除檔案或改可見性。已啟用 GitHub 郵箱隱私；這不會自動修正其他倉庫的既有提交。

## Checks and limits / 檢查與限制

Known source snapshots were checked for Telegram-style tokens, sk-style keys, private-key headers, the original student's identifier, private account mailbox and report identity strings. Credential-assignment hits were placeholders/synthetic tests. Source archives and original Git objects are not imported into the release. These checks are scoped, not a claim of exhaustive secret forensics; original shared credentials still need provider-side rotation.

The offline verification and documentation links pass. Earlier functional evidence remains: 27 regression tests and frontend type/no-lint build passed, ESLint failed, hardware/native iOS/model evaluation not reproduced. No new safety certification, whole-project open-source license or copyright registration is asserted.
