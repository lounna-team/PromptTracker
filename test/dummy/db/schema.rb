# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_01_04_000004) do
  create_table "prompt_tracker_evaluations", force: :cascade do |t|
    t.integer "llm_response_id", null: false
    t.decimal "score", precision: 10, scale: 2, null: false
    t.decimal "score_min", precision: 10, scale: 2, default: "0.0"
    t.decimal "score_max", precision: 10, scale: 2, default: "5.0"
    t.json "criteria_scores", default: {}
    t.string "evaluator_type", null: false
    t.string "evaluator_id"
    t.text "feedback"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evaluator_type", "created_at"], name: "index_evaluations_on_type_and_created_at"
    t.index ["evaluator_type"], name: "index_prompt_tracker_evaluations_on_evaluator_type"
    t.index ["llm_response_id"], name: "index_prompt_tracker_evaluations_on_llm_response_id"
    t.index ["score"], name: "index_evaluations_on_score"
  end

  create_table "prompt_tracker_llm_responses", force: :cascade do |t|
    t.integer "prompt_version_id", null: false
    t.text "rendered_prompt", null: false
    t.json "variables_used", default: {}
    t.text "response_text"
    t.json "response_metadata", default: {}
    t.string "status", default: "pending", null: false
    t.string "error_type"
    t.text "error_message"
    t.integer "response_time_ms"
    t.integer "tokens_prompt"
    t.integer "tokens_completion"
    t.integer "tokens_total"
    t.decimal "cost_usd", precision: 10, scale: 6
    t.string "provider", null: false
    t.string "model", null: false
    t.string "user_id"
    t.string "session_id"
    t.string "environment"
    t.json "context", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment"], name: "index_prompt_tracker_llm_responses_on_environment"
    t.index ["model"], name: "index_prompt_tracker_llm_responses_on_model"
    t.index ["prompt_version_id"], name: "index_prompt_tracker_llm_responses_on_prompt_version_id"
    t.index ["provider", "model", "created_at"], name: "index_llm_responses_on_provider_model_created_at"
    t.index ["provider"], name: "index_prompt_tracker_llm_responses_on_provider"
    t.index ["session_id"], name: "index_prompt_tracker_llm_responses_on_session_id"
    t.index ["status", "created_at"], name: "index_llm_responses_on_status_and_created_at"
    t.index ["status"], name: "index_prompt_tracker_llm_responses_on_status"
    t.index ["user_id"], name: "index_prompt_tracker_llm_responses_on_user_id"
  end

  create_table "prompt_tracker_prompt_versions", force: :cascade do |t|
    t.integer "prompt_id", null: false
    t.text "template", null: false
    t.integer "version_number", null: false
    t.string "status", default: "draft", null: false
    t.string "source", default: "file", null: false
    t.json "variables_schema", default: []
    t.json "model_config", default: {}
    t.text "notes"
    t.string "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prompt_id", "status"], name: "index_prompt_versions_on_prompt_and_status"
    t.index ["prompt_id", "version_number"], name: "index_prompt_versions_on_prompt_and_version_number", unique: true
    t.index ["prompt_id"], name: "index_prompt_tracker_prompt_versions_on_prompt_id"
    t.index ["source"], name: "index_prompt_tracker_prompt_versions_on_source"
    t.index ["status"], name: "index_prompt_tracker_prompt_versions_on_status"
  end

  create_table "prompt_tracker_prompts", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "category"
    t.json "tags", default: []
    t.string "created_by"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_prompt_tracker_prompts_on_archived_at"
    t.index ["category"], name: "index_prompt_tracker_prompts_on_category"
    t.index ["name"], name: "index_prompt_tracker_prompts_on_name", unique: true
  end

  add_foreign_key "prompt_tracker_evaluations", "prompt_tracker_llm_responses", column: "llm_response_id"
  add_foreign_key "prompt_tracker_llm_responses", "prompt_tracker_prompt_versions", column: "prompt_version_id"
  add_foreign_key "prompt_tracker_prompt_versions", "prompt_tracker_prompts", column: "prompt_id"
end
