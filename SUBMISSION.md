# Submission

Fork URL: <!-- paste the URL of your fork here -->

## Files to commit

- [ ] `requirements.yml`: the Galaxy collections your roles need
- [ ] `site.yml`: the playbook that applies your roles
- [ ] `roles/database/`, `roles/pollie/`, `roles/web/`: the three roles you write

## Questions

Answer in your own words. Where a question asks for output, paste it in a code block.

### Q1. Read the provided `roles/common/` first. Paste its directory tree (`tree roles/common` or `find`). What goes in `tasks/`, `defaults/`, `handlers/`, `templates/` and `meta/`, and why is `defaults/` the weakest place in the variable precedence order?

**Your answer:**

<!-- replace this line with your answer -->

### Q2. Paste the content of `roles/pollie/templates/pollie.env.j2` and the rendered file from the server (with the passwords hidden). Why does the database password need `| urlencode` in the URL but not in the PostgreSQL role task?

**Your answer:**

<!-- replace this line with your answer -->

### Q3. You used one template for both systemd units and a loop over `pollie_services`. Paste the loop in your tasks and one rendered unit. What would adding a third process (for example a scheduler) cost with this design, compared to copy-pasting a second unit file?

**Your answer:**

<!-- replace this line with your answer -->

### Q4. Paste `ansible-galaxy collection install` and your `requirements.yml`. Why pin versions of collections, and where would a team keep them?

**Your answer:**

<!-- replace this line with your answer -->

### Q5. Run `ansible-playbook site.yml -e pollie_log_level=debug`. Paste the recap and the handler lines. Which services restarted, on which hosts, and why only those? Run it again without `-e`: what happens to the file and the services?

**Your answer:**

<!-- replace this line with your answer -->

### Q6. Paste your PostgreSQL `pg_hba` rule and the `redis-cli ping` result without a password. Who can reach each service from where, and what would be wrong with `0.0.0.0/0`?

**Your answer:**

<!-- replace this line with your answer -->

### Q7. The end-to-end test: paste the `curl` commands you used to create a poll, vote and read the results through the web server. Name the four machines/processes the vote passed through, in order.

**Your answer:**

<!-- replace this line with your answer -->

### Q8. Run `ansible-playbook site.yml --tags pollie --check --diff` after stopping `pollie-worker` by hand on `pr-app`. Paste what Ansible says. What did tags let you avoid?

**Your answer:**

<!-- replace this line with your answer -->

### Q9. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.

**Your answer:**

<!-- replace this line with your answer -->

### Q10. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.

**Your answer:**

<!-- replace this line with your answer -->
