<?php

namespace OPNsense\EasyTier;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        // Redirect to the general settings page
        return $this->dispatcher->forward(array(
            "controller" => "general",
            "action" => "index"
        ));
    }
}
