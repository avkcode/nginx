# Extract Git metadata
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
GIT_COMMIT := $(shell git rev-parse --short HEAD)
GIT_REPO := $(shell git config --get remote.origin.url)

# Define labels
ENV_LABEL := app.environment:$(ENV)
GIT_BRANCH_LABEL := app.git/branch:$(GIT_BRANCH)
GIT_COMMIT_LABEL := app.git/commit:$(GIT_COMMIT)
GIT_REPO_LABEL := app.git/repo:$(GIT_REPO)
TEAM_LABEL := app.team:devops

# LABELS definition without trailing backslash
LABELS := \
    $(ENV_LABEL) \
    $(GIT_BRANCH_LABEL) \
    $(GIT_COMMIT_LABEL) \
    $(GIT_REPO_LABEL) \
    $(TEAM_LABEL)

define generate_labels
$(shell printf "    %s\n" $(patsubst %:,%: ,$(LABELS)))
endef
