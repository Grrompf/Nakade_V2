<?php
/**
 * Copyright (c) 2017 onAd Technologies - All Rights Reserved
 * All information contained herein is, and remains the property of onAd Technologies
 * and is protected by copyright law. Unauthorized copying of this file or any parts,
 * via any medium is strictly prohibited Proprietary and confidential.
 *
 * @author Dr. H.K. Maerz <holger.maerz@digital-trace.com>
 */

namespace AppBundle\Controller;

use Sensio\Bundle\FrameworkExtraBundle\Configuration\Route;
use Symfony\Bundle\FrameworkBundle\Controller\Controller;

class LuckyController extends Controller
{
    /**
     * @Route("/lucky/number")
     */
    public function numberAction()
    {
        $number = mt_rand(0, 100);

        return $this->render('lucky/number.html.twig', array(
            'number' => $number,
        ));
    }
}