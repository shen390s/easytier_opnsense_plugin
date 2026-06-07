<?php

/**
 *    Copyright (C) 2024 Deciso B.V.
 *
 *    All rights reserved.
 *
 *    Redistribution and use in source and binary forms, with or without
 *    modification, are permitted provided that the following conditions are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 *    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 *    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 *    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 *    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *    POSSIBILITY OF SUCH DAMAGE.
 *
 */

namespace OPNsense\EasyTier\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

class GeneralController extends ApiMutableModelControllerBase
{
    protected static $internalModelClass = '\OPNsense\EasyTier\EasyTier';
    protected static $internalModelName = 'easytier';

    public function getAction()
    {
        if ($this->request->isGet()) {
            return $this->getModel()->getNodes();
        }
        return [];
    }

    public function setAction()
    {
        $result = ['result' => 'failed'];
        if ($this->request->isPost()) {
            $postData = $this->request->getPost(static::$internalModelName);
            if (empty($postData)) {
                $jsonBody = $this->request->getJsonRawBody();
                if (is_array($jsonBody)) {
                    $postData = $jsonBody[static::$internalModelName] ?? $jsonBody;
                }
            }
            if (!empty($postData)) {
                Config::getInstance()->lock();
                $mdl = $this->getModel();
                $mdl->setNodes($postData);
                $result = $this->validate();
                if (empty($result['result'])) {
                    return $this->save(false, true);
                }
            }
        }
        return $result;
    }
}
