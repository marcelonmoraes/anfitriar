import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

import GuideModalController from "controllers/guide_modal_controller"
application.register("guide-modal", GuideModalController)

eagerLoadControllersFrom("controllers", application)

