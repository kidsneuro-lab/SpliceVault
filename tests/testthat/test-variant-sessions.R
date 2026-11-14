# Each user only ever sees the results of their own variant, however their
# clicks interleave with other users' on the same server. Both users are on the
# Variant tab (300K-RNA, the default): user A looks up an HBB variant (chr11)
# and user B an HBA1 variant (chr16). See test-variant.R for the recordings.

describe("Variant mode with two users on one server", {
  it("each user sees their own variant's table after the other has clicked", {
    with_two_users({
      # Given
      as_user(user_a, {
        user_opens_app(user_a)
        user_enters_variant(user_a, "NM_000518.5(HBB):c.316C>T")
      })
      as_user(user_b, {
        user_opens_app(user_b)
        user_enters_variant(user_b, "NM_000558.5(HBA1):c.95G>A")
      })
      ids_about_to_gain_a_digit()
      as_user(user_a, user_clicks(user_a, "Generate Table"))

      # When
      as_user(user_b, user_clicks(user_b, "Generate Table"))
      as_user(user_a, user_clicks(user_a, "Generate Table"))

      # Then
      as_user(user_a, {
        expect_table_title(user_a, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000518 (HBB) Acceptor 3 (max 2 exons skipped, cryptics within +/-600 nt)")
        expect_first_splice_junction(user_a, "chr11:5225727-5226576")
      })
      as_user(user_b, {
        expect_table_title(user_b, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000558 (HBA1) Donor 1 (max 2 exons skipped, cryptics within +/-600 nt)")
        expect_first_splice_junction(user_b, "chr16:176812-176928")
      })
    })
  })
})
